//
//  RectangleFeaturesFunnel.swift
//
//  Created by Jack on 2022/2/24.
//

import UIKit

/// 用来记录给定矩形是否匹配，及其匹配程度
final class RectangleMatch {
    
    let rectangle: Quadrilateral
    
    /// 记录目标矩形和漏斗中其他矩形的匹配程度，分数越高，表示接近程度越高
    var matchScore = 0
    
    init(rectangle: Quadrilateral) {
        self.rectangle = rectangle
    }
    
    var description: String {
        return "Matching score: \(matchScore) - Rectangle: \(rectangle)"
    }
}

/// 提高检测到的矩形的置信度，提供了对相似矩形进行比对，可以筛选出最佳匹配的矩形的算法
final class RectangleFeaturesFunnel {
    
    // MARK: - Properties
    /// 要比对的矩形队列，最新的排在队尾
    private var matches = [RectangleMatch]()
    
    /// 队列中最大可比对的矩形数量，增加这个值会影响性能，降低比对效率
    private let maxRectangleCount = 8
    /// 进行比对的最小矩形数量，增加这个值会影响首次结果产生的效率
    private let minRectangleCount = 3
    /// 矩形匹配阈值，以像素为单位，新结果生成的频率随值的增加而递减
    private let matchingThreshold: CGFloat = 40
    /// 只有当识别次数 similarMatchCount 大于等于 此值，才表明最终识别结果有效
    private let efficientMatchCount = 35
    
    /// 记录相似矩形匹配次数，结合 totalMatchCount 来确定是否是最后想要识别的区域
    var similarMatchCount = 0
    /// 是否可作为结果输出的参考匹配阈值，以像素为单位，值越大，生成结果的速度越快，但精准度越低
    var resultMatchingThreshold: CGFloat = 6
    
    // MARK: - Functions
    /**
     将矩形添加进队列，如果有新的最佳匹配的矩形数据，通过闭包 completion 返回结果
     
     - important: 筛选算法工作原理：
        1. 确保队列中有足够多的比对数据
        2. 将过旧的数据从队列中移除
        3. 对队列中的矩形进行相互比对，选出匹配分数最高的数据
        4. 如果最后选出的矩形和当前展示的矩形不同，则更新要展示的矩形
        5. 每当有新的近似匹配结果产生， similarMatchCount 就会+1，如果 totalMatchCount 超过了similarMatchCount，则会通过 completion 回调通知当前矩形区域可供进一步处理
        6. 直到 similarMatchCount >= totalMatchCount 时，就表明最终要识别的矩形区域已确定，通过 completion 返回最终结果
     - parameter rectangle: 要加入队列的矩形数据
     - parameter latestResult: 最近一次匹配成功的矩形，用来确定最终要识别的矩形区域，如果新矩形区域和其相似，则 similarMatchCount+1
     - parameter completion: 如果有新的最佳匹配的矩形数据，通过闭包 completion 返回结果，如果结果是最终要识别的区域，则返回true，否则返回false
     */
    func add(_ rectangle: Quadrilateral,  withlatestResult latestResult: Quadrilateral?, completion: (Bool, Quadrilateral) -> Void) {
        let match = RectangleMatch(rectangle: rectangle)
        matches.append(match)
        
        if matches.count < minRectangleCount {return}
        if matches.count > maxRectangleCount { matches.removeFirst() }
        
        updateRectanglesMatchScore()
        
        guard let bestMatch = bestMatch(withLatestResult: latestResult) else {return}
        
        if latestResult != nil,
           bestMatch.rectangle.isWithin(resultMatchingThreshold, ofQuadrilateral: latestResult!) {
            similarMatchCount += 1
            if similarMatchCount >= efficientMatchCount {
                similarMatchCount = 0
                completion(true, bestMatch.rectangle)
            }
        } else {
            completion(false, bestMatch.rectangle)
        }
    }
}

// MARK: - Private functions
extension RectangleFeaturesFunnel {
    
    /// 计算队列中矩形的匹配分数，对队列中的矩形进行两两比对，如果它们相似，就+1
    private func updateRectanglesMatchScore() {
        resetRectanglesMatchScore()
        for (i, currentRectangleMatch) in matches.enumerated() {
            for j in i..<matches.count {
                let match = matches[j]
                if match.rectangle.isWithin(matchingThreshold, ofQuadrilateral: currentRectangleMatch.rectangle) {
                    currentRectangleMatch.matchScore += 1
                    match.matchScore += 1
                }
            }
        }
    }
    
    /// 重置矩形的匹配分数
    private func resetRectanglesMatchScore() {
        for element in matches {
            element.matchScore = 0
        }
    }
    
    /// 通过匹配分数对别，选择大的生成匹配结果，如果矩形具有相同的匹配分数，则通过和 latestResult 进行进一步对比
    private func bestMatch(withLatestResult latestResult: Quadrilateral?) -> RectangleMatch? {
        var bestMatch: RectangleMatch?
        matches.forEach { match in
            if bestMatch == nil {
                bestMatch = match
                return
            }
            
            if bestMatch!.matchScore < match.matchScore {
                bestMatch = match
            } else if bestMatch!.matchScore == match.matchScore {
                if latestResult == nil {
                    bestMatch = match
                    return
                }
                
                bestMatch = breakTie(between: match, and: bestMatch!, latestResult: latestResult!)
            }
        }
        
        return bestMatch
    }
    
    private func breakTie(between match1: RectangleMatch, and match2: RectangleMatch, latestResult: Quadrilateral) -> RectangleMatch {
        if match1.rectangle.isWithin(matchingThreshold, ofQuadrilateral: latestResult) {
            return match1
        }
        
        if match2.rectangle.isWithin(matchingThreshold, ofQuadrilateral: latestResult) {
            return match2
        }
        
        return match1
    }
}
