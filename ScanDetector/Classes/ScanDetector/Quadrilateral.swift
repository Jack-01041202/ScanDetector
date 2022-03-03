//
//  Quadrilateral.swift
//
//  Created by Jack on 2022/2/23.
//

import UIKit
import Vision

public struct Quadrilateral {
    
    // MARK: - Properties
    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomLeft: CGPoint
    public var bottomRight: CGPoint
    
    /// 生成四边形路径
    var path: UIBezierPath {
        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()
        return path
    }
    
    /// 四边形周长
    var perimeter: CGFloat {
        return hypot(topLeft.x - topRight.x, topLeft.y - topRight.y) +
            hypot(topRight.x - bottomRight.x, topRight.x - bottomRight.y) +
            hypot(bottomRight.x - bottomLeft.x, bottomRight.y - bottomLeft.y) +
            hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y)
    }

    public var description: String {
        return "topLeft: \(topLeft), topRight: \(topRight), bottomLeft: \(bottomLeft), bottomRight: \(bottomRight)"
    }
    
    // MARK: - Initialize
    init(rectangleFeature: CIRectangleFeature) {
        self.topLeft = rectangleFeature.topLeft
        self.topRight = rectangleFeature.topRight
        self.bottomLeft = rectangleFeature.bottomLeft
        self.bottomRight = rectangleFeature.bottomRight
    }

    @available(iOS 11.0, *)
    init(rectangleObservation: VNRectangleObservation) {
        self.topLeft = rectangleObservation.topLeft
        self.topRight = rectangleObservation.topRight
        self.bottomLeft = rectangleObservation.bottomLeft
        self.bottomRight = rectangleObservation.bottomRight
    }

    init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }
    
    /// 对四边形进行放射变换，生成新的四边形
    func applying(_ transform: CGAffineTransform) -> Quadrilateral {
        return Quadrilateral(
            topLeft: topLeft.applying(transform),
            topRight: topRight.applying(transform),
            bottomRight: bottomRight.applying(transform),
            bottomLeft: bottomLeft.applying(transform)
        )
    }
    
    /**
     检查四边形是否在参考四边形给定的阈值范围之内
     
     - important: 分别以参考四边形的四个顶点为中心，所构成的四个正方形区域为参照，正方形的边长就是 threshold
     - parameter threshold: 阈值，容差值（以像素为单位）
     - returns: 在给定范围内，返回true；否则 false
     */
    func isWithin(_ threshold: CGFloat, ofQuadrilateral anotherQuad: Quadrilateral) -> Bool {
        let topLeftRect = CGRect(x: topLeft.x - threshold/2, y: topLeft.y - threshold/2, width: threshold, height: threshold)
        if !topLeftRect.contains(anotherQuad.topLeft) { return false }
        
        let topRightRect = CGRect(x: topRight.x - threshold/2, y: topRight.y - threshold/2, width: threshold, height: threshold)
        if !topRightRect.contains(anotherQuad.topRight) { return false }
        
        let bottomRightRect = CGRect(x: bottomRight.x - threshold/2, y: bottomRight.y - threshold/2, width: threshold, height: threshold)
        if !bottomRightRect.contains(anotherQuad.bottomRight) { return false }
        
        let bottomLeftRect = CGRect(x: bottomLeft.x - threshold/2, y: bottomLeft.y - threshold/2, width: threshold, height: threshold)
        if !bottomLeftRect.contains(anotherQuad.bottomLeft) { return false }
        
        return true
    }
    
    /// 根据给定的区域大小，缩放四边形四个顶点的坐标
    ///
    /// - Parameters:
    ///   - fromSize: 当前四边形顶点坐标对应的区域大小
    ///   - toSize: 要映射的区域大小
    ///   - angle: 应用旋转的角度 [可选]
    func scale(from fromSize: CGSize, to toSize: CGSize, rorate angle: CGFloat = 0.0) -> Quadrilateral {
        var invertedFromSize = CGSize(
            width: fromSize.width == 0 ? .leastNormalMagnitude : fromSize.width,
            height: fromSize.height == 0 ? .leastNormalMagnitude : fromSize.height
        )
        let rotated = angle != 0.0
        
        if rotated && angle != CGFloat.pi {
            invertedFromSize = CGSize(
                width: fromSize.height == 0 ? .leastNormalMagnitude : fromSize.height,
                height: fromSize.width == 0 ? .leastNormalMagnitude : fromSize.width
            )
        }
        
        var transformedQuad = self
        let scaleWidth = toSize.width / invertedFromSize.width
        let scaleHeight = toSize.height / invertedFromSize.height
        let scaledTransform = CGAffineTransform(scaleX: scaleWidth, y: scaleHeight)
        
        // 映射到toSize大小后的坐标
        transformedQuad = transformedQuad.applying(scaledTransform)
        
        if rotated {
            let rotationTransform = CGAffineTransform(rotationAngle: angle)
            
            let fromImageBounds = CGRect(origin: .zero, size: fromSize).applying(scaledTransform).applying(rotationTransform)
            let toImageBounds = CGRect(origin: .zero, size: toSize)
            
            let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: fromImageBounds, toCenterOfRect: toImageBounds)
            
            // 变换后，坐标系转为物理坐标系
            transformedQuad = transformedQuad.applying(rotationTransform).applying(translationTransform)
        }
        
        return transformedQuad
    }
    
    /// 以图片的高度（识别区域）为基准，通过反转y轴得到坐标系内四边形四个顶点的坐标
    func toCartesian(withHeight height: CGFloat) -> Quadrilateral {
        let topLeft = CGPoint(x: topLeft.x, y: height - topLeft.y)
        let topRight = CGPoint(x: topRight.x, y: height - topRight.y)
        let bottomRight = CGPoint(x: bottomRight.x, y: height - bottomRight.y)
        let bottomLeft = CGPoint(x: bottomLeft.x, y: height - bottomLeft.y)
        
        return Quadrilateral(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
    }
    
    /// 判断两个四边新区域是否完全相同
    public static func == (lhs: Quadrilateral, rhs: Quadrilateral) -> Bool {
        return lhs.topLeft == rhs.topLeft && lhs.topRight == rhs.topRight && lhs.bottomRight == rhs.bottomRight && lhs.bottomLeft == rhs.bottomLeft
    }
}
