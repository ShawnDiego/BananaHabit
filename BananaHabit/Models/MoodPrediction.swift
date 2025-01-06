import Foundation

struct MoodPrediction {
    let nextHighestDays: Int  // 预计多少天后可能出现最高分
    let nextLowestDays: Int   // 预计多少天后可能出现最低分
    let confidence: Double
    
    static func predict(from moods: [Mood]) -> MoodPrediction {
        guard moods.count >= 3 else {
            return MoodPrediction(nextHighestDays: 0, nextLowestDays: 0, confidence: 0)
        }
        
        let sortedMoods = moods.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        
        // 找到最近的最高分和最低分记录
        let highestMoods = sortedMoods.filter { $0.value == 5 }
        let lowestMoods = sortedMoods.filter { $0.value == 1 }
        
        // 计算最高分和最低分的平均间隔天数
        func calculateAverageInterval(_ moodRecords: [Mood]) -> Double {
            guard moodRecords.count >= 2 else { return 30 } // 默认30天
            
            var totalDays = 0
            for i in 1..<moodRecords.count {
                let days = calendar.dateComponents([.day], from: moodRecords[i-1].date, to: moodRecords[i].date).day ?? 0
                totalDays += days
            }
            return Double(totalDays) / Double(moodRecords.count - 1)
        }
        
        // 计算距离下一次的天数
        func calculateNextOccurrence(_ moodRecords: [Mood], averageInterval: Double) -> Int {
            guard let lastRecord = moodRecords.last else { return 30 }
            let daysSinceLastRecord = calendar.dateComponents([.day], from: lastRecord.date, to: Date()).day ?? 0
            let predictedDays = Int(round(averageInterval)) - daysSinceLastRecord
            return max(1, predictedDays)
        }
        
        let highestInterval = calculateAverageInterval(highestMoods)
        let lowestInterval = calculateAverageInterval(lowestMoods)
        
        let nextHighestDays = calculateNextOccurrence(highestMoods, averageInterval: highestInterval)
        let nextLowestDays = calculateNextOccurrence(lowestMoods, averageInterval: lowestInterval)
        
        // 计算置信度
        let confidence = max(0.0, min(1.0, Double(moods.count) / 30.0))
        
        return MoodPrediction(
            nextHighestDays: nextHighestDays,
            nextLowestDays: nextLowestDays,
            confidence: confidence
        )
    }
} 