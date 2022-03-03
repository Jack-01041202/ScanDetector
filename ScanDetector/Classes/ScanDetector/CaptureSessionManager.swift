//
//  CaptureSessionManager.swift
//
//  Created by Jack on 2022/2/23.
//

import UIKit
import AVFoundation

/// 用于回调通知检测结果和状态
public protocol RectangleDetectionDelegateProtocol: NSObjectProtocol {
    
    /// 当检测到图像中物体边缘区域时回调
    /// - Parameters:
    ///   - captureSessionManager: CaptureSessionManager实例，用以边缘检测和图片捕获
    ///   - quad: 在图片所在坐标系内检测到的四边形边缘区域.
    ///   - imageSize: 用来进行物体边缘检测的图片尺寸.
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize)
    
    /// 识别完成矩形区域完成，进行捕获
    func didStartCapturingImage(for captureSessionManager: CaptureSessionManager)
    
    /// 完成图片内目标物体边缘的识别和捕获，回调返回最终结果
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?)
    
    /// 在捕获图像过程中产生错误时回调
    func captureSessionManager(_ manager: CaptureSessionManager, didFailWithError error: CaptureError)
}

public final class CaptureSessionManager: NSObject {

    // MARK: - Properties
    public let device: AVCaptureDevice?
    public weak var delegate: RectangleDetectionDelegateProtocol?
    
    private let videoPreviewLayer: AVCaptureVideoPreviewLayer
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private let config: CaptureConfig
    
    /// 是否正在检测物体边缘
    private(set) var isDetecting: Bool = false
    /// 用来筛选出最佳矩形识别结果
    private let rectangleFunnel = RectangleFeaturesFunnel()
    /// 识别过程中，未找到矩形区域的次数
    private var noRectangleCount = 0
    /// 如果  `noRectangleCount` 超过此阈值，说明当前区域没有能识别到的矩形，此值用来修正检测时的偏差，不宜过大或过小
    private let noRectangleThreshold = 5
    /// 记录最新一次的边缘检测结果
    private var latestDetectResult: RectangleDetectorResult?
    /// 是否正在拍照捕获图片
    private var isCapturing: Bool = false
    
    // MARK: - Initialize
    init?(withConfig config: CaptureConfig, previewLayer: AVCaptureVideoPreviewLayer, delegate: RectangleDetectionDelegateProtocol? = nil) {
        self.config = config
        self.videoPreviewLayer = previewLayer
        self.delegate = delegate
        self.device = AVCaptureDevice.default(for: .video)
        super.init()
        
        // 获取输入设备
        guard device != nil else {
            delegate?.captureSessionManager(self, didFailWithError: .invalidDevice)
            return nil
        }
        
        // 配置
        captureSession.beginConfiguration()
        
        let photoPreset = AVCaptureSession.Preset.photo
        if captureSession.canSetSessionPreset(photoPreset) {
            captureSession.sessionPreset = photoPreset
        }
        
        photoOutput.isHighResolutionCaptureEnabled = true
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        defer {
            device!.unlockForConfiguration()
            captureSession.commitConfiguration()
        }
        
        do {
            try device!.lockForConfiguration()
        } catch {
            delegate?.captureSessionManager(self, didFailWithError: .invalidDevice)
            return nil
        }
        
        device!.isSubjectAreaChangeMonitoringEnabled = true
        
        // 添加输入输出
        guard let deviceInput = try? AVCaptureDeviceInput(device: device!),
              captureSession.canAddInput(deviceInput),
              captureSession.canAddOutput(photoOutput),
              captureSession.canAddOutput(videoOutput)
        else {
            delegate?.captureSessionManager(self, didFailWithError: .invalidIO)
            return nil
        }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)
              
        videoPreviewLayer.session = captureSession
        videoPreviewLayer.videoGravity = .resizeAspectFill
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video_ouput_queue"))
    }
    
    // MARK: Capture Session Life Cycle
    /// 打开摄像头并开始检测边缘
    public func start() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authorizationStatus {
        case .authorized:
            DispatchQueue.main.async { self.captureSession.startRunning() }
            isDetecting = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (_) in
                DispatchQueue.main.async { self.start() }
            })
        default:
            delegate?.captureSessionManager(self, didFailWithError: .unauthorized)
        }
    }
    
    /// 停止检测
    public func stop() {
        isDetecting = false
        rectangleFunnel.similarMatchCount = 0
        DispatchQueue.main.async { self.captureSession.stopRunning() }
    }
    
    /// 停止检测，拍摄最终要捕获的照片
    public func capturePhoto() {
        guard let connection = photoOutput.connection(with: .video),
              connection.isEnabled,
              connection.isActive
        else {
            delegate?.captureSessionManager(self, didFailWithError: .invalidCapture)
            return
        }
        
        config.setImageOrientation()
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        if #available(iOS 13.0, *) {
            photoSettings.photoQualityPrioritization = .balanced
        } else {
            photoSettings.isAutoStillImageStabilizationEnabled = true
        }
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        DispatchQueue.main.async { self.delegate?.didStartCapturingImage(for: self) }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CaptureSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isDetecting,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        
        // 利用近似区域识别和比对算法，处理检测结果
        let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        RectangleDetector.detect(for: pixelBuffer) { self.proccess(rectangle: $0, imageSize: imageSize) }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CaptureSessionManager: AVCapturePhotoCaptureDelegate {
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        stop()
        
        if error != nil {
            delegate?.captureSessionManager(self, didFailWithError: .invalidIO)
            return
        }
        
        if let sampleBuffer = photoSampleBuffer,
           let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: nil) {
            completeImageCapture(with: imageData)
        } else {
            delegate?.captureSessionManager(self, didFailWithError: .invalidCapture)
        }
    }
    
    @available(iOS 11.0, *)
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        stop()
        
        if error != nil {
            delegate?.captureSessionManager(self, didFailWithError: .invalidIO)
            return
        }
        
        if let imageData = photo.fileDataRepresentation() {
            completeImageCapture(with: imageData)
        } else {
            delegate?.captureSessionManager(self, didFailWithError: .invalidCapture)
        }
    }
}

// MARK: - Actions
extension CaptureSessionManager {
    
    /// 重新自动聚焦
    func resetFocusToAuto() {
        defer {
            device?.unlockForConfiguration()
            captureSession.commitConfiguration()
        }
        
        do {
            try device?.lockForConfiguration()
        } catch {
            delegate?.captureSessionManager(self, didFailWithError: .invalidDevice)
            return
        }
        
        device?.focusMode = .continuousAutoFocus
        device?.exposureMode = .continuousAutoExposure
    }
    
    /// 设置闪光灯模式
    func setTorchMode(_ mode: AVCaptureDevice.TorchMode) {
        defer {
            device?.unlockForConfiguration()
            captureSession.commitConfiguration()
        }
        
        do {
            try device?.lockForConfiguration()
        } catch {
            delegate?.captureSessionManager(self, didFailWithError: .invalidDevice)
            return
        }
        
        device?.torchMode = mode
    }
}

// MARK: - Private functions
extension CaptureSessionManager {
    
    private func completeImageCapture(with imageData: Data) {
        defer { isCapturing = false }
        DispatchQueue.global(qos: .background).async {
            guard let image = UIImage(data: imageData) else {
                DispatchQueue.main.async {
                    self.delegate?.captureSessionManager(self, didFailWithError: .invalidCapture)
                }
                return
            }
            
            // iOS下，Home键朝右为正向拍照模式
            // AVCapturePhoto生成ImageData，拍照之后的 图片方向 总是 .right
            var angle: CGFloat = 0
            if image.imageOrientation == .right {
                angle = CGFloat.pi / 2
            }
            
            var quad: Quadrilateral?
            
            // latestDetectResult参考坐标系：正向拍照模式，原点在手机左上角，x向右，y向上
            if let result = self.latestDetectResult {
                // 坐标系原点变为右上角，x向右，y向下
                quad = self.transformRectangleResult(rectangleResult: result)
                // 缩放四个顶点坐标，映射到实际拍摄图片的像素大小
                quad = quad?.scale(from: result.imageSize, to: image.size, rorate: angle)
            }

            DispatchQueue.main.async {
                self.delegate?.captureSessionManager(self, didCapturePicture: image, withQuad: quad)
            }
        }
    }
    
    private func proccess(rectangle: Quadrilateral?, imageSize: CGSize) {
        if let rectangle = rectangle {
            noRectangleCount = 0
            rectangleFunnel.add(rectangle, withlatestResult: latestDetectResult?.rectangle) { isFinal, rect in
                
                transformRectangleResult(rectangleResult: RectangleDetectorResult(rectangle: rect, imageSize: imageSize))
                if isFinal, !isCapturing, config.isAutoCaptureEnabled {
                    isCapturing = true
                    capturePhoto()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.noRectangleCount += 1
                
                if self.noRectangleCount > self.noRectangleThreshold {
                    // 当前区域确实没有可识别的矩形，重置 similarMatchCount
                    self.rectangleFunnel.similarMatchCount = 0
                    self.latestDetectResult = nil
                    self.delegate?.captureSessionManager(self, didDetectQuad: nil, imageSize)
                }
            }
        }
    }
    
    @discardableResult private func transformRectangleResult(rectangleResult: RectangleDetectorResult) -> Quadrilateral {
        latestDetectResult = rectangleResult
        
        let imageSize = rectangleResult.imageSize
        var quad = rectangleResult.rectangle.toCartesian(withHeight: imageSize.height)
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        let areaSize = config.cameraAreaFrame.size
        
        // 保持图片宽高比不变，映射到 quadContainerSize
        let scaleTransform = CGAffineTransform.scaleTransform(
            from: portraitImageSize,
            aspectFillInSize: areaSize
        )
        let scaledImageSize = imageSize.applying(scaleTransform)
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)
        let toRect = CGRect(origin: .zero, size: areaSize)
        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: toRect)
        
        quad = quad.applying(scaleTransform).applying(rotationTransform).applying(translationTransform)
        DispatchQueue.main.async {
            self.delegate?.captureSessionManager(self, didDetectQuad: quad, rectangleResult.imageSize)
        }
        
        return quad
    }
}
