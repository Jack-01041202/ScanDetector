//
//  RectangleDetector.swift
//
//  Created by Jack on 2022/2/23.
//

import Foundation
import Vision
import CoreImage

/// 矩形区域识别结果
struct RectangleDetectorResult {
    
    public let rectangle: Quadrilateral
    public let imageSize: CGSize
}

struct RectangleDetector {
    
    // 频繁创建 CIDetector 会占用大量系统资源，这里使用单例进行共用
    private static let shared = CIDetector(
        ofType: CIDetectorTypeRectangle,
        context: nil,
        options: [
            CIDetectorAccuracy: CIDetectorAccuracyHigh,
            CIDetectorAspectRatio: 0.2
        ]
    )
    
    /// 创建矩形检测请求，并实时生成检测结果
    @available(iOS 11.0, *)
    private static func performDetectRequest(_ request: VNImageRequestHandler, imageSize: CGSize, completion: @escaping ((Quadrilateral?) -> Void)) {
        let detectRequest = VNDetectRectanglesRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNRectangleObservation],
                  !results.isEmpty
            else {
                completion(nil)
                return
            }
            
            // 在检测到的矩形中选择最大的
            let quads = results.map {Quadrilateral(rectangleObservation: $0)}
            guard let maxQuad = quads.max(by: { $0.perimeter < $1.perimeter }) else {return}
            
            // 使用仿射变换将检测到的矩形四个顶点坐标从归一化坐标系转换为图片所在坐标系坐标
            let transform = CGAffineTransform.identity.scaledBy(x: imageSize.width, y: imageSize.height)
            completion(maxQuad.applying(transform))
        }
        
        detectRequest.minimumConfidence = 0.7
        detectRequest.minimumAspectRatio = 0.2
        detectRequest.maximumObservations = 15
        
        do { try request.perform([detectRequest]) }
        catch { completion(nil) }
    }
    
    /// 从图片采样的缓冲区中检测矩形
    static func detect(for pixelBuffer: CVPixelBuffer, completion: @escaping ((Quadrilateral?) -> Void)) {
        if #available(iOS 11.0, *) {
            let request = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
            let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            performDetectRequest(request, imageSize: size, completion: completion)
        } else {
            detect(for: CIImage(cvPixelBuffer: pixelBuffer), completion: completion)
        }
    }
    
    /// 从给定图片中进行矩形检测
    static func detect(for image: CIImage, orientation: CGImagePropertyOrientation? = nil, completion: @escaping ((Quadrilateral?) -> Void)) {
        if #available(iOS 11.0, *) {
            let request = VNImageRequestHandler(ciImage: image)
            var newImage = image
            if orientation != nil {
                newImage = image.oriented(orientation!)
            }
            let size = CGSize(width: newImage.extent.width, height: newImage.extent.height)
            performDetectRequest(request, imageSize: size, completion: completion)
        } else {
            guard let features = shared?.features(in: image) as? [CIRectangleFeature] else {
                completion(nil)
                return
            }
            
            // 在检测到的矩形中选择最大的
            let quads = features.map {Quadrilateral(rectangleFeature: $0)}
            guard let maxQuad = quads.max(by: { $0.perimeter < $1.perimeter }) else {return}
            completion(maxQuad)
        }
    }
}
