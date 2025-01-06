import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddItem = false
    @EnvironmentObject private var userVM: UserViewModel
    @State private var showingUserProfile = false
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            mainContent
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingUserProfile = true
                        } label: {
                            HStack(spacing: 8) {
                                if userVM.isAuthenticated, let user = userVM.currentUser {
                                    Text("\(userVM.getGreeting())，\(user.name)")
                                        .font(.subheadline)
                                    
                                    if let avatarUrl = user.avatarUrl {
                                        AsyncImage(url: URL(fileURLWithPath: avatarUrl)) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                            .frame(width: 40, height: 40)
                                    }
                                } else {
                                    Text("未登录")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "person.circle")
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingUserProfile) {
            if !userVM.isAuthenticated {
                SignInView()
                    .environmentObject(userVM)
            } else {
                UserProfileView()
                    .environmentObject(userVM)
            }
        }
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
                Section("最近七天心情趋势") {
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
                    
                    HStack(spacing: 12) {
                        // 最差心情
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最差")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let worst = getWorstMood() {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(moodColor(worst.value))
                                        .frame(width: 8, height: 8)
                                    Text("\(formatDate(worst.date)) (\(daysAgo(from: worst.date))天前)")
                                        .font(.subheadline)
                                }
                            } else {
                                Text("暂无")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // 最好心情
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("最好")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let best = getBestMood() {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(moodColor(best.value))
                                        .frame(width: 8, height: 8)
                                    Text("\(formatDate(best.date)) (\(daysAgo(from: best.date))天前)")
                                        .font(.subheadline)
                                }
                            } else {
                                Text("暂无")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
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
    
    // 添加新的辅助方法
    private func getWorstMood() -> Mood? {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let recentMoods = items.flatMap { $0.moods }.filter { $0.date >= thirtyDaysAgo }
        return recentMoods.min { $0.value < $1.value || ($0.value == $1.value && $0.date > $1.date) }
    }
    
    private func getBestMood() -> Mood? {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let recentMoods = items.flatMap { $0.moods }.filter { $0.date >= thirtyDaysAgo }
        return recentMoods.max { $0.value < $1.value || ($0.value == $1.value && $0.date < $1.date) }
    }
    
    private func daysAgo(from date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let moodDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: moodDate, to: today)
        return components.day ?? 0
    }
    
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red.opacity(0.8)
        case 2: return .orange.opacity(0.8)
        case 3: return .yellow.opacity(0.8)
        case 4: return .mint.opacity(0.8)
        case 5: return .blue.opacity(0.8)
        default: return .gray.opacity(0.8)
        }
    }
    
    // 添加日期格式化函数
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// 周心情图表组件
struct WeekMoodChart: View {
    let items: [Item]
    
    var body: some View {
        Chart {
            ForEach(weekData().filter { $0.value > 0 }, id: \.date) { data in
                LineMark(
                    x: .value("日期", data.date, unit: .day),
                    y: .value("心情", data.value)
                )
                .foregroundStyle(moodColor(data.value))
                .symbol {
                    Circle()
                        .fill(moodColor(data.value))
                        .frame(width: 10, height: 10)
                }
                
                AreaMark(
                    x: .value("日期", data.date, unit: .day),
                    y: .value("心情", data.value)
                )
                .foregroundStyle(
                    Gradient(colors: [moodColor(data.value).opacity(0.2), .clear])
                )
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
    
    // 获取最近一周数据
    private func weekData() -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).compactMap { day in
            // 从今天开始往前推算7天
            let date = calendar.date(byAdding: .day, value: -(6-day), to: today)!
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
    
    // 添加心情颜色函数
    private func moodColor(_ value: Double) -> Color {
        switch Int(round(value)) {
        case 1: return .red.opacity(0.8)
        case 2: return .orange.opacity(0.8)
        case 3: return .yellow.opacity(0.8)
        case 4: return .mint.opacity(0.8)
        case 5: return .blue.opacity(0.8)
        default: return .gray.opacity(0.8)
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
                    Image(systemName: value <= currentValue ? "circle.fill" : "circle")
                        .foregroundStyle(moodColor(value))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
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
    
    // 添加心情颜色函数
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red.opacity(0.8)
        case 2: return .orange.opacity(0.8)
        case 3: return .yellow.opacity(0.8)
        case 4: return .mint.opacity(0.8)
        case 5: return .blue.opacity(0.8)
        default: return .gray
        }
    }
}
