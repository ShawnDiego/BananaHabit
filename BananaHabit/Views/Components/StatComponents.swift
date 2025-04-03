import SwiftUI

struct StatItemView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// 统计卡片视图
struct StatsOverviewCard: View {
    let item: Item
    let diaries: [Diary]
    let records: [PomodoroRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("统计概览")
                .font(.headline)
            
            // 心情统计
            VStack(alignment: .leading, spacing: 8) {
                Text("心情记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    StatItemView(
                        title: "本周平均",
                        value: String(format: "%.1f", weeklyAverageMood(item)),
                        icon: "chart.bar.fill",
                        color: .blue
                    )
                    
                    StatItemView(
                        title: "连续记录",
                        value: "\(consecutiveRecordDays(item))天",
                        icon: "flame.fill",
                        color: .orange
                    )
                }
            }
            
            Divider()
            
            // 专注统计
            VStack(alignment: .leading, spacing: 8) {
                Text("专注记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    StatItemView(
                        title: "本周专注",
                        value: "\(weeklyFocusTime())分钟",
                        icon: "timer",
                        color: .purple
                    )
                    
                    StatItemView(
                        title: "完成次数",
                        value: "\(weeklyCompletedCount())次",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
            
            if !diaries.isEmpty {
                Divider()
                
                // 日记统计
                VStack(alignment: .leading, spacing: 8) {
                    Text("日记记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        StatItemView(
                            title: "本周日记",
                            value: "\(weeklyDiaryCount())篇",
                            icon: "doc.text.fill",
                            color: .purple
                        )
                        
                        StatItemView(
                            title: "总日记数",
                            value: "\(diaries.count)篇",
                            icon: "books.vertical.fill",
                            color: .green
                        )
                    }
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                if let worst = getWorstMood(item) {
                    MoodExtremeView(
                        title: "最低心情",
                        date: worst.date,
                        value: worst.value,
                        color: .red
                    )
                }
                
                if let best = getBestMood(item) {
                    MoodExtremeView(
                        title: "最高心情",
                        date: best.date,
                        value: best.value,
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
    }
    
    // 计算本周平均心情
    private func weeklyAverageMood(_ item: Item) -> Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        var totalValue = 0
        var count = 0
        
        for mood in item.moods {
            if calendar.isDate(mood.date, equalTo: startOfWeek, toGranularity: .weekOfYear) {
                totalValue += mood.value
                count += 1
            }
        }
        
        return count > 0 ? Double(totalValue) / Double(count) : 0
    }
    
    // 计算连续记录天数
    private func consecutiveRecordDays(_ item: Item) -> Int {
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        var consecutiveDays = 0
        
        while true {
            if !item.moods.contains(where: { calendar.isDate($0.date, inSameDayAs: currentDate) }) {
                break
            }
            
            consecutiveDays += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return consecutiveDays
    }
    
    // 计算本周日记数量
    private func weeklyDiaryCount() -> Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        return diaries.filter { diary in
            calendar.isDate(diary.createdAt, equalTo: startOfWeek, toGranularity: .weekOfYear)
        }.count
    }
    
    // 计算本周专注总时长（分钟）
    private func weeklyFocusTime() -> Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        let weeklyRecords = records.filter { record in
            calendar.isDate(record.startTime, equalTo: startOfWeek, toGranularity: .weekOfYear)
        }
        
        let totalSeconds = weeklyRecords.reduce(0) { $0 + $1.duration }
        return Int(totalSeconds / 60)
    }
    
    // 计算本周完成的番茄钟次数
    private func weeklyCompletedCount() -> Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        return records.filter { record in
            calendar.isDate(record.startTime, equalTo: startOfWeek, toGranularity: .weekOfYear) && record.isCompleted
        }.count
    }
    
    private func getWorstMood(_ item: Item) -> Mood? {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let recentMoods = item.moods.filter { $0.date >= thirtyDaysAgo }
        return recentMoods.min { $0.value < $1.value || ($0.value == $1.value && $0.date > $1.date) }
    }
    
    private func getBestMood(_ item: Item) -> Mood? {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let recentMoods = item.moods.filter { $0.date >= thirtyDaysAgo }
        return recentMoods.max { $0.value < $1.value || ($0.value == $1.value && $0.date < $1.date) }
    }
} 