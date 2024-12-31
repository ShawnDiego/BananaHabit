import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddItem = false
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            mainContent
        }
        .navigationViewStyle(.stack)
        #else
        NavigationStack {
            mainContent
        }
        #endif
    }
    
    private var mainContent: some View {
        List {
            Section("今日心情速记") {
                if items.isEmpty {
                    Text("还没有添加任何事项")
                        .foregroundColor(.gray)
                } else {
                    ForEach(items) { item in
                        QuickMoodRow(item: item)
                            .id(item.id)
                    }
                }
            }
            
            if !items.isEmpty {
                Section("本周心情趋势") {
                    WeekMoodChart(items: items)
                        .frame(height: 200)
                }
                
                Section("统计概览") {
                    HStack {
                        Text("本周平均心情")
                        Spacer()
                        Text(String(format: "%.1f", weeklyAverageMood()))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("记录天数")
                        Spacer()
                        Text("\(consecutiveRecordDays())天")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("概览")
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
    }
    
    // 计算本周平均心情
    private func weeklyAverageMood() -> Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        var totalValue = 0
        var count = 0
        
        for item in items {
            for mood in item.moods {
                if calendar.isDate(mood.date, equalTo: startOfWeek, toGranularity: .weekOfYear) {
                    totalValue += mood.value
                    count += 1
                }
            }
        }
        
        return count > 0 ? Double(totalValue) / Double(count) : 0
    }
    
    // 计算连续记录天数
    private func consecutiveRecordDays() -> Int {
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        var consecutiveDays = 0
        
        while true {
            var hasRecord = false
            for item in items {
                if item.moods.contains(where: { calendar.isDate($0.date, inSameDayAs: currentDate) }) {
                    hasRecord = true
                    break
                }
            }
            
            if !hasRecord {
                break
            }
            
            consecutiveDays += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return consecutiveDays
    }
}

// 周心情图表组件
struct WeekMoodChart: View {
    let items: [Item]
    
    var body: some View {
        Chart {
            ForEach(weekData(), id: \.date) { data in
                LineMark(
                    x: .value("日期", data.date, unit: .day),
                    y: .value("心情", data.value)
                )
                .symbol(Circle())
                
                AreaMark(
                    x: .value("日期", data.date, unit: .day),
                    y: .value("心情", data.value)
                )
                .foregroundStyle(Gradient(colors: [.blue.opacity(0.3), .clear]))
            }
        }
        .chartYScale(domain: 0...5)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
        }
    }
    
    // 获取周数据
    private func weekData() -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        return (0..<7).compactMap { day in
            let date = calendar.date(byAdding: .day, value: day, to: startOfWeek)!
            var totalValue = 0
            var count = 0
            
            for item in items {
                if let mood = item.moods.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    totalValue += mood.value
                    count += 1
                }
            }
            
            let averageValue = count > 0 ? Double(totalValue) / Double(count) : 0
            return (date: date, value: averageValue)
        }
    }
}

struct QuickMoodRow: View {
    @Bindable var item: Item
    @State private var showingNote = false
    @State private var note: String = ""
    @State private var currentValue: Int
    
    init(item: Item) {
        self.item = item
        let initialValue = item.moods.first { Calendar.current.isDateInToday($0.date) }?.value ?? 0
        _currentValue = State(initialValue: initialValue)
        _note = State(initialValue: item.moods.first { Calendar.current.isDateInToday($0.date) }?.note ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name)
                Spacer()
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= currentValue ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            withAnimation {
                                currentValue = value
                                updateMood(value: value)
                            }
                        }
                }
            }
            
            if let mood = getTodayMood(), !mood.note.isEmpty {
                Text(mood.note)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .onTapGesture {
                        note = mood.note
                        showingNote = true
                    }
            }
        }
        .sheet(isPresented: $showingNote) {
            NavigationView {
                Form {
                    Section("添加备注") {
                        TextField("今天的感受...", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .navigationTitle("心情备注")
//                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            note = getTodayMood()?.note ?? ""
                            showingNote = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if let mood = getTodayMood() {
                                mood.note = note
                            }
                            showingNote = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func getTodayMood() -> Mood? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return item.moods.first { calendar.isDate($0.date, inSameDayAs: today) }
    }
    
    private func updateMood(value: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let existingMood = getTodayMood() {
            existingMood.value = value
            existingMood.date = today
        } else {
            let newMood = Mood(date: today, value: value, note: note, item: item)
            item.moods.append(newMood)
        }
    }
}
