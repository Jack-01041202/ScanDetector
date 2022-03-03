//
//  CaptureViewController.swift
//
//  Created by Jack on 2022/3/2.
//

import UIKit
import AVFoundation

public final class CaptureViewController: UIViewController {
    
    // MARK: - Properties
    public let captureConfig: CaptureConfig
    public let quadViewConfig: QuadViewConfig
    
    private var captureSessionManager: CaptureSessionManager?
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var focusView: FocusRectangleView?
    private lazy var quadView: QuadView = {
        let view = QuadView(withConfig: quadViewConfig)
        return view
    }()
    
    
    // MARK: - Life cycle
    public init(withCaptureConfig captureConfig: CaptureConfig? = nil, quadViewConfig: QuadViewConfig? = nil) {
        self.captureConfig = captureConfig ?? CaptureConfig()
        self.quadViewConfig = quadViewConfig ?? QuadViewConfig()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        captureSessionManager = CaptureSessionManager(
            withConfig: self.captureConfig,
            previewLayer: previewLayer,
            delegate: self
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subjectAreaDidChange),
            name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange,
            object: nil
        )
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
    }
    
    override public func viewDidLayoutSubviews() {
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    
        captureSessionManager?.stop()
        captureSessionManager?.device?.torchMode = .off
    }
}

// MARK: - Actions
extension CaptureViewController {
    
    /// 设置闪光灯模式
    public func setTorchMode(_ mode: AVCaptureDevice.TorchMode) {
        captureSessionManager?.setTorchMode(mode)
    }
    
    /// 开始更新配置，更新前进行调用，完成更新后必须调用 `endUpdateConfigs()` 应用更新项
    public func beginUpdateConfigs() {
        captureSessionManager?.stop()
        quadView.removeQuadrilateral()
        focusView?.remove(animated: false)
    }
    
    /// 完成配置更新，完成设置后调用，修改配置前必须调用 `beginUpdateConfigs()`
    public func endUpdateConfigs() {
        updateFrame()
        captureSessionManager?.start()
        captureSessionManager?.resetFocusToAuto()
    }
    
    /// 手动拍摄捕获图片
    public func captureImage() {
        view.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }
    
    /// 是否识别完自动捕获图片
    public func openAutoCapture(_ isAuto: Bool) {
        captureConfig.isAutoCaptureEnabled(isAuto)
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if !captureConfig.isShowAutoFocus {return}
        
        guard let touch = touches.first else { return }
        let touchPoint = touch.location(in: view)
        focus(at: touchPoint)
    }
}

// MARK: - Private functions
extension CaptureViewController {
    
    private func setupUI() {
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        view.addSubview(quadView)
        updateFrame()
    }
    
    private func updateFrame() {
        previewLayer.frame = captureConfig.cameraAreaFrame
        quadView.frame = captureConfig.cameraAreaFrame
    }
    
    // 重新自动聚焦
    @objc private func subjectAreaDidChange() {
        captureSessionManager?.resetFocusToAuto()
        focusView?.remove(animated: true)
    }
    
    private func focus(at point: CGPoint) {
        let convertedTouchPoint: CGPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        if !previewLayer.contains(convertedTouchPoint) { return }
        
        captureSessionManager?.resetFocusToAuto()
        focusView?.remove(animated: false)
        if captureConfig.isShowAutoFocus {
            focusView = FocusRectangleView(touchPoint: point)
            view.addSubview(focusView!)
        }
    }
}

// MARK: - RectangleDetectionDelegateProtocol
extension CaptureViewController: RectangleDetectionDelegateProtocol {
    
    public func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad = quad else {
            quadView.removeQuadrilateral()
            return
        }
        quadView.drawQuadrilateral(quad, animated: true)
    }
    
    public func didStartCapturingImage(for captureSessionManager: CaptureSessionManager) {
        view.isUserInteractionEnabled = false
        captureSessionManager.stop()
    }
    
    public func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        view.isUserInteractionEnabled = true
    }
    
    public func captureSessionManager(_ manager: CaptureSessionManager, didFailWithError error: CaptureError) {
        view.isUserInteractionEnabled = true
    }
}
