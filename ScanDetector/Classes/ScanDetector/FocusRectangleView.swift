//
//  FocusRectangleView.swift
//
//  Created by Jack on 2022/3/3.
//

import UIKit

/// 聚焦框
final public class FocusRectangleView: UIView {
    
    convenience init(touchPoint: CGPoint) {
        let originalSize: CGFloat = 200
        let finalSize: CGFloat = 80
        
        // Here, we create the frame to be the `originalSize`, with it's center being the `touchPoint`.
        self.init(frame: CGRect(x: touchPoint.x - (originalSize / 2), y: touchPoint.y - (originalSize / 2), width: originalSize, height: originalSize))
        
        backgroundColor = .clear
        layer.borderWidth = 1.5
        layer.cornerRadius = 5
        layer.borderColor = UIColor.yellow.cgColor
        
        // Here, we animate the rectangle from the `originalSize` to the `finalSize` by calculating the difference.
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
            self.frame.origin.x += (originalSize - finalSize) / 2
            self.frame.origin.y += (originalSize - finalSize) / 2
            
            self.frame.size.width -= (originalSize - finalSize)
            self.frame.size.height -= (originalSize - finalSize)
        })
    }
    
    public func setBorder(color: CGColor) {
        layer.borderColor = color
    }
}

// MARK: - Actions
extension FocusRectangleView {
    
    /// 移除聚焦框
    public func remove(animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0.8, animations: {
                self.alpha = 0.0
            }, completion: { _ in
                self.removeFromSuperview()
            })
        } else {
            removeFromSuperview()
        }
    }
}

