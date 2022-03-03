//
//  CaptureConfig.swift
//
//  Created by Jack on 2022/2/23.
//

import UIKit
import AVFoundation
import CoreMotion

public enum CaptureError: Error, LocalizedError {
    
    /// 用户没有授权访问相机
    case unauthorized
    /// 无法使用输入设备
    case invalidDevice
    /// 输入输出错误
    case invalidIO
    /// 捕获图像时发生错误
    case invalidCapture
    
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Failed to get the user's authorization for camera."
        case .invalidDevice:
            return "Could not setup input device."
        case .invalidIO:
            return "Cound not input or output data through capture session."
        case .invalidCapture:
            return "Could not capture picture."
        }
    }
}

/// 有关图片捕获的参数配置
public final class CaptureConfig {
    
    /// 是否显示聚焦框
    private(set) var isShowAutoFocus: Bool = true
    
    /// 捕获后图片需要调整的方向，默认为 .up
    private(set) var imageFixedOrientation: CGImagePropertyOrientation = .up
    
    /// 是否开启识别完成后自动拍照捕获，默认为 true
    private(set) var isAutoCaptureEnabled: Bool = true
    
    /// 相机预览层的 frame，默认为屏幕范围
    private(set) var cameraAreaFrame: CGRect = UIScreen.main.bounds
    
    /// 是否显示聚焦框
    @discardableResult public func idShowAutoFocus(_ isShow: Bool) -> CaptureConfig {
        isShowAutoFocus = isShow
        return self
    }
    
    /// 是否开启识别完成后自动拍照捕获，默认为 true
    @discardableResult public func isAutoCaptureEnabled(_ isEnable: Bool) -> CaptureConfig {
        isAutoCaptureEnabled = isEnable
        return self
    }
    
    /// 相机预览层的 frame，默认为屏幕范围
    @discardableResult public func setCameraAreaFrame(_ frame: CGRect) -> CaptureConfig {
        cameraAreaFrame = frame
        return self
    }
    
    public init() {}
}

// MARK: - Detect Image orientation
extension CaptureConfig {
    
    /// 通过检测设备方向来调整图片的方向，调整为正向
    func setImageOrientation() {
        let motion = CMMotionManager()
        guard motion.isAccelerometerAvailable else {return}
        motion.accelerometerUpdateInterval = 0.01
        
        motion.startAccelerometerUpdates(to: OperationQueue()) { data, error in
            guard let data = data, error == nil else { return }
            
            /// 判定设备横向的最小阈值
            let motionThreshold = 0.35
            
            // 设备向右横置，编码图片调整为向左旋转90度后的结果
            if data.acceleration.x >= motionThreshold {
                self.imageFixedOrientation = .left
                
            // 设备向左横置，编码图片调整为向右旋转90度后的结果
            } else if data.acceleration.x <= -motionThreshold {
                self.imageFixedOrientation = .right
                
            // 不考虑倒置手机
            } else {
                self.imageFixedOrientation = .up
            }
            
            motion.stopAccelerometerUpdates()
            
            // 开启屏幕旋转后，貌似坐标轴会产生变化，横向放置手机拍摄时，加速计会判定是正向放置
            // 但实际图片是横向结果，因此这里用设备持握方向做进一步判定和纠正
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                self.imageFixedOrientation = .right
            case .landscapeRight:
                self.imageFixedOrientation = .left
            default:
                break
            }
        }
    }
}
