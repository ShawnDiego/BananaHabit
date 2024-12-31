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
    @State private var isDragging = false
    @State private var currentDateOffset = 0  // 添加日期偏移量状态
    @GestureState private var dragOffset: CGFloat = 0
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
                
                HStack {
                    Button(action: { changeOffset(-1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                    
                    Picker("时间范围", selection: $selectedScale) {
                        ForEach(TimeScale.allCases, id: \.self) { scale in
                            Text(scale.rawValue).tag(scale)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedScale) { _, _ in
                        currentDateOffset = 0  // 切换时间范围时重置偏移量
                    }
                    
                    Button(action: { changeOffset(1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                    .disabled(currentDateOffset >= 0)  // 禁止向未来滑动
                }
                .padding(.horizontal)
                
                // 固定高度的容器来显示选中信息
                ZStack(alignment: .leading) {
                    if isDragging, let selectedMood = selectedMood {
                        HStack {
                            Text(selectedMood.date.formatted(.dateTime.year().month().day()))
                            Text("心情: \(selectedMood.value)分")
                                .foregroundColor(moodColor(selectedMood.value))
                            if !selectedMood.note.isEmpty {
                                Text("备注: \(selectedMood.note)")
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                    }
                }
                .frame(height: 20) // 固定高度
                .padding(.horizontal)
                
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
                    
                    if isDragging, let selectedMood = selectedMood {
                        RuleMark(
                            x: .value("选中日期", selectedMood.date)
                        )
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        
                        RuleMark(
                            y: .value("选中心情", selectedMood.value)
                        )
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    }
                }
                .frame(height: 200)
                .chartXScale(domain: chartDateRange)
                .chartYScale(domain: 0...5)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let xPosition = value.location.x
                                    if let date = proxy.value(atX: xPosition, as: Date.self) {
                                        withAnimation(.interactiveSpring()) {
                                            selectedMood = findClosestMood(to: date)
                                        }
                                    }
                                }
                                .onEnded { value in
                                    // 判断是否为滑动切换
                                    let threshold: CGFloat = 50
                                    if abs(value.translation.width) > threshold {
                                        if value.translation.width > 0 {
                                            changeOffset(-1)
                                        } else {
                                            changeOffset(1)
                                        }
                                    }
                                    
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        isDragging = false
                                        selectedMood = nil
                                    }
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
                HStack{
                    Text("心情分布")
                        .font(.headline)
                    Spacer()
                }
                
                
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
    
    private func changeOffset(_ delta: Int) {
        // 防止向未来滑动
        if delta > 0 && currentDateOffset >= 0 {
            return
        }
        withAnimation {
            currentDateOffset += delta
        }
    }
    
    private var chartDateRange: ClosedRange<Date> {
        let endDate: Date
        let startDate: Date
        
        switch selectedScale {
        case .week:
            endDate = calendar.date(byAdding: .day, value: 7 * currentDateOffset, to: Date())!
            startDate = calendar.date(byAdding: .day, value: -6, to: endDate)!
        case .month:
            endDate = calendar.date(byAdding: .month, value: currentDateOffset, to: Date())!
            startDate = calendar.date(byAdding: .day, value: -29, to: endDate)!
        case .halfYear:
            endDate = calendar.date(byAdding: .month, value: 6 * currentDateOffset, to: Date())!
            startDate = calendar.date(byAdding: .month, value: -6, to: endDate)!
        case .year:
            endDate = calendar.date(byAdding: .year, value: currentDateOffset, to: Date())!
            startDate = calendar.date(byAdding: .month, value: -12, to: endDate)!
        }
        
        return startDate...min(endDate, Date())  // 确保不超过当前日期
    }
    
    private var filteredMoods: [Mood] {
        let range = chartDateRange
        return item.moods
            .filter { $0.date >= range.lowerBound && $0.date <= range.upperBound }
            .sorted { $0.date < $1.date }
    }
    
    private func moodCount(_ value: Int) -> Int {
        filteredMoods.filter { $0.value == value }.count
    }
    
    // 添加查找最近心情记录的方法
    private func findClosestMood(to date: Date) -> Mood? {
        let filteredMoods = self.filteredMoods
        guard !filteredMoods.isEmpty else { return nil }
        
        return filteredMoods.min { mood1, mood2 in
            let interval1 = abs(mood1.date.timeIntervalSince(date))
            let interval2 = abs(mood2.date.timeIntervalSince(date))
            return interval1 < interval2
        }
    }
} 