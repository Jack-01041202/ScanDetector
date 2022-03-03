//
//  EditableCornerView.swift
//
//  Created by Jack on 2022/3/1.
//

import UIKit

/// 编辑时用来确定追踪的四边形顶点
enum TrackCornerOptions {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
}

final class EditableCornerView: UIView {

    /// 追踪的顶角
    let trackCorner: TrackCornerOptions
    
    /// 是否选中顶角
    private(set) var isHighlighted = false
    
    /// 设置顶角编辑区域的边框颜色
    var strokeColor: CGColor? {
        willSet {
            circleLayer.strokeColor = newValue
        }
    }
    
    /// 用来放大展示所编辑的顶角区域
    private var image: UIImage?
    
    private lazy var circleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 1.0
        return layer
    }()
    
    init(frame: CGRect, trackCorner: TrackCornerOptions) {
        self.trackCorner = trackCorner
        super.init(frame: frame)
        
        backgroundColor = UIColor.clear
        clipsToBounds = true
        layer.addSublayer(circleLayer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2.0
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let bezierPath = UIBezierPath(ovalIn: rect.insetBy(dx: circleLayer.lineWidth, dy: circleLayer.lineWidth))
        circleLayer.frame = rect
        circleLayer.path = bezierPath.cgPath
        
        image?.draw(in: rect)
    }
    
    func highlight(withImage image: UIImage) {
        isHighlighted = true
        self.image = image
        setNeedsDisplay()
    }
    
    func reset() {
        isHighlighted = false
        image = nil
        setNeedsDisplay()
    }
}
