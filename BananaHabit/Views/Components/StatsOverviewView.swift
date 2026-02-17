import SwiftUI
import SwiftData
import Charts

// MARK: - 统计汇总视图
struct StatsOverviewView: View {
    let items: [Item]
    let diaries: [Diary]
    let records: [PomodoroRecord]
    
    var body: some View {
        VStack(spacing: 20) {
            // 心情趋势卡片
            moodTrendCard
            
            // 统计概览卡片
            if let firstItem = items.first {
                StatsOverviewCard(item: firstItem, diaries: diaries, records: records)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 心情趋势卡片
    @ViewBuilder
    private var moodTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("心情趋势")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("最近7天")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !weekData.isEmpty {
                WeekMoodChart(data: weekData)
                    .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("暂无心情数据")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("开始记录你的心情变化")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
    }
    
    // MARK: - 获取最近一周数据
    private var weekData: [(Date, Double)] {
        let calendar = Calendar.current
        let today = Date()
        var data: [(Date, Double)] = []
        
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayMoods = items.flatMap { item in
                    item.moods.filter { calendar.isDate($0.date, inSameDayAs: date) }
                }
                
                if !dayMoods.isEmpty {
                    let average = Double(dayMoods.map { $0.value }.reduce(0, +)) / Double(dayMoods.count)
                    data.append((date, average))
                }
            }
        }
        
        return data.sorted { $0.0 < $1.0 }
    }
}

// MARK: - 周心情图表
struct WeekMoodChart: View {
    let data: [(Date, Double)]
    
    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                LineMark(
                    x: .value("日期", item.0),
                    y: .value("心情", item.1)
                )
                .foregroundStyle(MoodUtils.moodColor(item.1))
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                PointMark(
                    x: .value("日期", item.0),
                    y: .value("心情", item.1)
                )
                .foregroundStyle(MoodUtils.moodColor(item.1))
                .symbolSize(60)
            }
        }
        .chartYScale(domain: 1...5)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                if let intValue = value.as(Int.self) {
                    AxisValueLabel {
                        Text(MoodUtils.moodText(intValue))
                            .font(.caption2)
                    }
                }
            }
        }
    }
    

}

#Preview {
    StatsOverviewView(items: [], diaries: [], records: [])
}