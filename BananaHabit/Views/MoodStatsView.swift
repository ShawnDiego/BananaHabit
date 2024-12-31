import SwiftUI
import Charts

enum TimeScale: String, CaseIterable {
    case week = "周"
    case month = "月"
    case halfYear = "半年"
    case year = "年"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .halfYear: return 180
        case .year: return 365
        }
    }
}

struct MoodStatsView: View {
    @Bindable var item: Item
    @State private var selectedScale: TimeScale = .week
    @State private var selectedMood: Mood?
    private let calendar = Calendar.current
    
    // 心情分数对应的颜色
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 图表容器
            VStack(alignment: .leading, spacing: 12) {
                Text("心情趋势")
                    .font(.headline)
                    .padding(.horizontal)
                
                Picker("时间范围", selection: $selectedScale) {
                    ForEach(TimeScale.allCases, id: \.self) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 选中的数据点信息
                if let selectedMood = selectedMood {
                    HStack {
                        Text(selectedMood.date.formatted(.dateTime.year().month().day()))
                        Text("心情: \(selectedMood.value)分")
                            .foregroundColor(moodColor(selectedMood.value))
                        let note = selectedMood.note
                        if !note.isEmpty {
                            Text("备注: \(note)")
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                }
                
                // 心情趋势图表
                Chart {
                    ForEach(filteredMoods) { mood in
                        PointMark(
                            x: .value("日期", mood.date),
                            y: .value("心情", mood.value)
                        )
                        .foregroundStyle(moodColor(mood.value))
                        .symbolSize(60)
                        .symbol(.circle)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                switch selectedScale {
                                case .week:
                                    Text(date.formatted(.dateTime.day()))
                                case .month:
                                    Text(date.formatted(.dateTime.day()))
                                case .halfYear:
                                    Text(date.formatted(.dateTime.month()))
                                case .year:
                                    Text(date.formatted(.dateTime.month()))
                                }
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5])
                }
                .chartYScale(domain: 0.5...5.5)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        guard let date = proxy.value(atX: x) as Date? else { return }
                                        
                                        selectedMood = filteredMoods
                                            .min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
                                    }
                                    .onEnded { _ in
                                        selectedMood = nil
                                    }
                            )
                    }
                }
            }
            .padding(.vertical)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            
            // 心情分布统计容器
            VStack(spacing: 12) {
                Text("心情分布")
                    .font(.headline)
                
                HStack(spacing: 15) {
                    ForEach(1...5, id: \.self) { value in
                        VStack(spacing: 6) {
                            Text("\(moodCount(value))")
                                .font(.system(.title3, design: .rounded))
                                .bold()
                            HStack(spacing: 2) {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(moodColor(value))
                                Text("\(value)分")
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(moodColor(value), lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
        .padding()
    }
    
    private var filteredMoods: [Mood] {
        let endDate = Date()
        var startDate: Date
        
        switch selectedScale {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate)!
        case .halfYear:
            startDate = calendar.date(byAdding: .month, value: -6, to: endDate)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: endDate)!
        }
        
        return item.moods
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date < $1.date }
    }
    
    private func moodCount(_ value: Int) -> Int {
        filteredMoods.filter { $0.value == value }.count
    }
} 