//
//  QuadView.swift
//
//  Created by Jack on 2022/3/1.
//

import UIKit
import AVFoundation

/// 用来绘制和展示检测到的四边形区域
public class QuadView: UIView {

    // MARK: - Properties
    /// 有关区域显示的属性配置
    public let config: QuadViewConfig
    /// 要绘制的四边形区域
    private(set) var quad: Quadrilateral?
    
    /// 是否可以进行拖拽顶点进行区域编辑
    private(set) var editable: Bool! {
        willSet {
            setCornerViews(hidden: !newValue)
            quadLayer.fillColor = newValue ? UIColor(white: 0.0, alpha: 0.6).cgColor : config.fillColorDetecting
            
            guard let quad = quad else { return }
            drawQuad(quad, animated: false)
            layoutCornerViews(forQuad: quad)
        }
    }
    
    private var isHighlighted = false {
        willSet {
            guard newValue != isHighlighted else {return}
            quadLayer.fillColor = isHighlighted ? UIColor.clear.cgColor : UIColor(white: 0.0, alpha: 0.6).cgColor
            isHighlighted ? bringSubviewToFront(quadView) : sendSubviewToBack(quadView)
        }
    }
    
    var strokeColor: CGColor? {
        willSet {
            quadLayer.strokeColor = newValue
            topLeftCornerView.strokeColor = newValue
            topRightCornerView.strokeColor = newValue
            bottomRightCornerView.strokeColor = newValue
            bottomLeftCornerView.strokeColor = newValue
        }
    }
    
    private lazy var quadLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = config.strokeColor
        layer.lineWidth = 1.0
        layer.opacity = 1.0
        layer.isHidden = true
        
        return layer
    }()
    
    private let quadView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var topLeftCornerView: EditableCornerView = {
        return EditableCornerView(frame: CGRect(origin: .zero, size: CGSize(width: config.cornerViewRadius, height: config.cornerViewRadius)), trackCorner: .topLeft)
    }()
    
    private lazy var topRightCornerView: EditableCornerView = {
        return EditableCornerView(frame: CGRect(origin: .zero, size: CGSize(width: config.cornerViewRadius, height: config.cornerViewRadius)), trackCorner: .topRight)
    }()
    
    private lazy var bottomRightCornerView: EditableCornerView = {
        return EditableCornerView(frame: CGRect(origin: .zero, size: CGSize(width: config.cornerViewRadius, height: config.cornerViewRadius)), trackCorner: .bottomRight)
    }()
    
    private lazy var bottomLeftCornerView: EditableCornerView = {
        return EditableCornerView(frame: CGRect(origin: .zero, size: CGSize(width: config.cornerViewRadius, height: config.cornerViewRadius)), trackCorner: .bottomLeft)
    }()
    
    // MARK: - Initialize
    public init(withConfig config: QuadViewConfig) {
        self.config = config
        super.init(frame: .zero)
        setValue(config.editable, forKey: "editable")
        
        addSubview(quadView)
        quadView.layer.addSublayer(quadLayer)
        if editable { setupCornerViews() }
        makeConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    public override func setValue(_ value: Any?, forUndefinedKey key: String) {
        guard let value = value as? Bool else {return}
        editable = value
    }
    
    public override func layoutSubviews() {
        guard quadLayer.frame != bounds else { return }
        
        quadLayer.frame = bounds
        if let quad = quad { drawQuadrilateral(quad, animated: false) }
    }
    
    // MARK: - Drawing
    /// 绘制四边形区域
    ///
    /// - Parameters:
    ///   - quad: 所绘制展示的区域，必须在 QuadrilateralView 所在坐标系区域内
    public func drawQuadrilateral(_ quad: Quadrilateral, animated: Bool) {
        self.quad = quad
        drawQuad(quad, animated: animated)
        if editable {
            setCornerViews(hidden: false)
            layoutCornerViews(forQuad: quad)
        }
    }
    
    /// 移除四边形区域
    public func removeQuadrilateral() {
        quadLayer.path = nil
        quadLayer.isHidden = true
    }
    
    // MARK: - Actions
    /// 移动顶角到指定的位置
    func moveCorner(cornerView: EditableCornerView, to point: CGPoint) {
        guard let quad = quad else { return }
        
        let fixedPoint = fixPoint(point)
        cornerView.center = fixedPoint
        
        let updatedQuad = update(quad, withPosition: fixedPoint, forCorner: cornerView.trackCorner)
        self.quad = updatedQuad
        
        drawQuadrilateral(updatedQuad, animated: false)
    }
    
    /// 聚焦显示顶角
    func focusCorner(_ corner: TrackCornerOptions, with image: UIImage) {
        guard editable else { return }
        isHighlighted = true
        
        let cornerView = cornerView(for: corner)
        guard cornerView.isHighlighted == false else {
            cornerView.highlight(withImage: image)
            return
        }

        let origin = CGPoint(
            x: cornerView.frame.origin.x - (config.highlightedCornerViewRadius - config.cornerViewRadius) / 2.0,
            y: cornerView.frame.origin.y - (config.highlightedCornerViewRadius - config.cornerViewRadius) / 2.0
        )
        cornerView.frame = CGRect(
            origin: origin,
            size: CGSize(width: config.highlightedCornerViewRadius, height: config.highlightedCornerViewRadius)
        )
        cornerView.highlight(withImage: image)
    }
    
    func resetHighlightedCornerViews() {
        isHighlighted = false
        [topLeftCornerView,
         topRightCornerView,
         bottomLeftCornerView,
         bottomRightCornerView]
        .forEach { resetHightlightedCornerView($0)}
    }
}

// MARK: - Private functions
extension QuadView {
    
    private func setupCornerViews() {
        addSubview(topLeftCornerView)
        addSubview(topRightCornerView)
        addSubview(bottomRightCornerView)
        addSubview(bottomLeftCornerView)
    }
    
    private func makeConstraints() {
        let quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: topAnchor),
            quadView.leadingAnchor.constraint(equalTo: leadingAnchor),
            quadView.bottomAnchor.constraint(equalTo: bottomAnchor),
            quadView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ]
        
        NSLayoutConstraint.activate(quadViewConstraints)
    }
    
    private func drawQuad(_ quad: Quadrilateral, animated: Bool) {
        var path = quad.path
        
        if editable {
            path = path.reversing()
            let rectPath = UIBezierPath(rect: bounds)
            path.append(rectPath)
        }
        
        if animated {
            let pathAnimation = CABasicAnimation(keyPath: "path")
            pathAnimation.duration = 0.2
            quadLayer.add(pathAnimation, forKey: "path")
        }
        
        quadLayer.path = path.cgPath
        quadLayer.isHidden = false
    }
    
    private func setCornerViews(hidden: Bool) {
        topLeftCornerView.isHidden = hidden
        topRightCornerView.isHidden = hidden
        bottomRightCornerView.isHidden = hidden
        bottomLeftCornerView.isHidden = hidden
    }
    
    private func layoutCornerViews(forQuad quad: Quadrilateral) {
        topLeftCornerView.center = quad.topLeft
        topRightCornerView.center = quad.topRight
        bottomLeftCornerView.center = quad.bottomLeft
        bottomRightCornerView.center = quad.bottomRight
    }
    
    /// 确保要移动到的点在 QuadrilateralView 范围之内
    private func fixPoint(_ point: CGPoint) -> CGPoint {
        var validPoint = point
        
        if point.x > bounds.width {
            validPoint.x = bounds.width
        } else if point.x < 0.0 {
            validPoint.x = 0.0
        }
        
        if point.y > bounds.height {
            validPoint.y = bounds.height
        } else if point.y < 0.0 {
            validPoint.y = 0.0
        }
        
        return validPoint
    }
    
    private func update(_ quad: Quadrilateral, withPosition position: CGPoint, forCorner corner: TrackCornerOptions) -> Quadrilateral {
        var quad = quad
        
        switch corner {
        case .topLeft:
            quad.topLeft = position
        case .topRight:
            quad.topRight = position
        case .bottomRight:
            quad.bottomRight = position
        case .bottomLeft:
            quad.bottomLeft = position
        }
        
        return quad
    }
    
    private func cornerView(for corner: TrackCornerOptions) -> EditableCornerView {
        switch corner {
        case .topLeft:
            return topLeftCornerView
        case .topRight:
            return topRightCornerView
        case .bottomLeft:
            return bottomLeftCornerView
        case .bottomRight:
            return bottomRightCornerView
        }
    }
    
    private func resetHightlightedCornerView(_ cornerView: EditableCornerView) {
        cornerView.reset()
        let origin = CGPoint(
            x: cornerView.frame.origin.x + (cornerView.frame.size.width - config.cornerViewRadius) / 2.0,
            y: cornerView.frame.origin.y + (cornerView.frame.size.height - config.cornerViewRadius) / 2.0
        )
        cornerView.frame = CGRect(
            origin: origin,
            size: CGSize(width: config.cornerViewRadius, height: config.cornerViewRadius)
        )
        cornerView.setNeedsDisplay()
    }
}
