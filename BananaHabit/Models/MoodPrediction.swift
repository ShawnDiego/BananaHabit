import Foundation
import SwiftData

// 添加导入Mood模型
// 由于我们看不到完整的项目结构，如果需要额外导入，请相应调整
// import BananaHabit

struct MoodPrediction {
    // 预测未来三天的心情值
    let day1Score: Int
    let day2Score: Int
    let day3Score: Int
    let confidence: Double
    
    struct DayPrediction {
        let score: Int
        let probability: Double
    }
    
    static func predict(from moods: [Mood]) -> MoodPrediction {
        guard moods.count >= 3 else {
            // 数据不足时返回中等心情值
            return MoodPrediction(day1Score: 3, day2Score: 3, day3Score: 3, confidence: 0.0)
        }
        
        let calendar = Calendar.current
        let sortedMoods = moods.sorted { $0.date < $1.date }
        
        // 获取最近的心情记录
        let recentMoods = Array(sortedMoods.suffix(min(14, sortedMoods.count)))
        
        // 计算最近记录的平均分和趋势
        var trend = 0.0
        if recentMoods.count >= 3 {
            // 计算近期趋势斜率
            let xValues = Array(0..<recentMoods.count).map { Double($0) }
            let yValues = recentMoods.map { Double($0.value) }
            trend = calculateLinearTrend(x: xValues, y: yValues)
        }
        
        // 计算天数到星期几的映射
        func dayOfWeek(forDaysFromNow days: Int) -> Int {
            let date = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
            return calendar.component(.weekday, from: date) // 1是周日，7是周六
        }
        
        // 根据星期几分析过去的记录模式
        func scorePatternForWeekday(_ weekday: Int) -> DayPrediction {
            // 过滤出同一星期几的记录
            let sameWeekdayMoods = sortedMoods.filter {
                calendar.component(.weekday, from: $0.date) == weekday
            }
            
            if sameWeekdayMoods.isEmpty {
                // 如果没有这个星期几的数据，使用总体平均值
                let avgScore = sortedMoods.reduce(0) { $0 + $1.value } / max(1, sortedMoods.count)
                return DayPrediction(score: avgScore, probability: 0.3)
            }
            
            // 计算这个星期几的平均分
            let totalScore = sameWeekdayMoods.reduce(0) { $0 + $1.value }
            let avgScore = totalScore / sameWeekdayMoods.count
            
            // 计算这个星期几的一致性
            var consistency = 0.0
            if sameWeekdayMoods.count > 1 {
                let variance = sameWeekdayMoods.map { pow(Double($0.value - avgScore), 2.0) }.reduce(0.0, +)
                consistency = 1.0 - min(1.0, sqrt(variance / Double(sameWeekdayMoods.count)) / 2.0)
            }
            
            // 根据数据量调整概率
            let dataFactor = min(1.0, Double(sameWeekdayMoods.count) / 4.0)
            let probability = 0.3 + (0.6 * dataFactor * consistency)
            
            return DayPrediction(score: avgScore, probability: probability)
        }
        
        // 预测未来三天的分数
        func predictScoreForDay(_ dayFromNow: Int) -> Int {
            let weekday = dayOfWeek(forDaysFromNow: dayFromNow)
            let weekdayPattern = scorePatternForWeekday(weekday)
            
            // 计算最近的平均分
            let recentAvg = recentMoods.reduce(0) { $0 + $1.value } / max(1, recentMoods.count)
            
            // 线性趋势预测值
            let trendPrediction = max(1, min(5, Int(round(Double(recentAvg) + trend * Double(dayFromNow)))))
            
            // 综合考虑星期几模式和趋势
            let patternWeight = weekdayPattern.probability
            let trendWeight = 1.0 - patternWeight
            
            let combinedScore = Double(weekdayPattern.score) * patternWeight + Double(trendPrediction) * trendWeight
            return Int(round(combinedScore))
        }
        
        // 计算合适置信度
        let dataConfidence = min(1.0, Double(moods.count) / 14.0)
        let recencyConfidence = min(1.0, Double(recentMoods.count) / 7.0)
        let confidence = (dataConfidence * 0.4) + (recencyConfidence * 0.6)
        
        // 预测未来三天
        let day1 = predictScoreForDay(1)
        let day2 = predictScoreForDay(2)
        let day3 = predictScoreForDay(3)
        
        return MoodPrediction(
            day1Score: day1,
            day2Score: day2,
            day3Score: day3,
            confidence: confidence
        )
    }
    
    // 计算线性趋势斜率
    private static func calculateLinearTrend(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0.0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0.0, +)
        let sumY = y.reduce(0.0, +)
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0.0, +)
        let sumXSquare = x.map { $0 * $0 }.reduce(0.0, +)
        
        // 计算线性回归斜率: (n*∑xy - ∑x*∑y) / (n*∑x² - (∑x)²)
        let numerator = n * sumXY - sumX * sumY
        let denominator = n * sumXSquare - sumX * sumX
        
        return denominator != 0 ? numerator / denominator : 0
    }
} 
