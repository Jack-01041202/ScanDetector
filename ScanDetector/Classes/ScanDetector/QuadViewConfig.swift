//
//  QuadViewConfig.swift
//
//  Created by Jack on 2022/3/1.
//

import UIKit

/// 用来配置展示检测区域的样式
public final class QuadViewConfig {
    
    /// 是否可编辑选取
    private(set) var editable: Bool = false
    
    /// 可编辑顶角的展示半径，默认为 20
    private(set) var cornerViewRadius: CGFloat = 20
    
    /// 高亮状态下的顶角展示半径，默认为 75
    private(set) var highlightedCornerViewRadius: CGFloat = 75
    
    /// 四边形描边颜色
    private(set) var strokeColor: CGColor? = UIColor.blue.cgColor
    
    /// 检测状态下四边形填充颜色
    private(set) var fillColorDetecting: CGColor? = UIColor(red: 0, green: 0.2, blue: 1, alpha: 0.5).cgColor
    
    @discardableResult public func setEditable(_ editable: Bool) -> QuadViewConfig {
        self.editable = editable
        return self
    }
    
    @discardableResult public func setCornerViewRadius(_ radius: CGFloat) -> QuadViewConfig {
        cornerViewRadius = radius
        return self
    }
    
    @discardableResult public func setHighlightedCornerViewRadius(_ radius: CGFloat) -> QuadViewConfig {
        highlightedCornerViewRadius = radius
        return self
    }
    
    @discardableResult public func setStrokeColor(_ color: CGColor?) -> QuadViewConfig {
        strokeColor = color
        return self
    }
    
    @discardableResult public func setFillColorDetecting(_ color: CGColor?) -> QuadViewConfig {
        fillColorDetecting = color
        return self
    }
    
    public init() { }
}
