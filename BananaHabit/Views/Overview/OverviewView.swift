import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query private var diaries: [Diary]
    @Query(sort: \PomodoroRecord.startTime, order: .reverse) private var records: [PomodoroRecord]
    @State private var showingAddItem = false
    @EnvironmentObject private var userVM: UserViewModel
    @State private var showingUserProfile = false
    @State private var showingMoodInput = false
    @State private var selectedItemId: PersistentIdentifier?
    @State private var isItemSelectorExpanded = false
    
    var selectedItem: Item? {
        if let selectedItemId = selectedItemId {
            return items.first { $0.persistentModelID == selectedItemId }
        }
        return items.first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户信息头部
                    userProfileHeader
                    
                    if items.isEmpty {
                        emptyStateView
                    } else {
                        // 事项选择器
                        VStack(spacing: 8) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(items) { item in
                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedItemId = item.persistentModelID
                                            }
                                        } label: {
                                            VStack(spacing: 6) {
                                                ItemIconView(
                                                    icon: item.icon,
                                                    size: 24,
                                                    color: selectedItemId == item.persistentModelID ? .blue : .gray
                                                )
                                                Text(item.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(selectedItemId == item.persistentModelID ? .blue : .primary)
                                            }
                                            .frame(width: 80, height: 80)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(selectedItemId == item.persistentModelID ? 
                                                        Color.blue.opacity(0.1) : 
                                                        Color(.systemBackground))
                                                    .shadow(color: .black.opacity(0.1), radius: 5)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    Button {
                                        showingAddItem = true
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.blue)
                                            Text("添加事项")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                        }
                                        .frame(width: 80, height: 80)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                .background(Color.blue.opacity(0.05))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        if let item = selectedItem {
                            // 今日心情卡片
                            VStack {
                                if hasTodayMood(item) {
                                    TodayMoodView(item: item)
                                        .padding(.horizontal)
                                        .frame(height: 120)
                                } else {
                                    Button {
                                        showingMoodInput = true
                                    } label: {
                                        VStack(spacing: 16) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.blue)
                                            
                                            Text("记录今天的心情")
                                                .font(.headline)
                                            
                                            Text("每日记录帮助你更好地了解自己")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 180)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color(.tertiarySystemBackground))
                                                .shadow(color: .black.opacity(0.1), radius: 10)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            VStack(spacing: 16) {
                                // 心情趋势图表
                                moodTrendCard(item: item)
                                    .padding(.horizontal)
                                
                                Divider()
                                    .padding(.horizontal)
                                    .frame(height: 2)
                                    .background(Color(.systemBackground))
                                    
                                
                                // 统计数据卡片
                                statsOverviewCard(item: item)
                                    .padding(.horizontal)
                            }
                            // .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingUserProfile) {
            if !userVM.isAuthenticated {
                SignInView()
                    .environmentObject(userVM)
            } else {
                UserProfileView()
                    .environmentObject(userVM)
            }
        }
        .sheet(isPresented: $showingMoodInput) {
            if let item = selectedItem {
                QuickMoodInputView(preSelectedItem: item)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .onAppear {
            if selectedItemId == nil, let firstItem = items.first {
                selectedItemId = firstItem.persistentModelID
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            // 主要的添加习惯卡片
            VStack(spacing: 24) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                
                VStack(spacing: 12) {
                    Text("开始记录你的第一个事项心情")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("添加一个你想要记录的事项\n观察每天的心情变化")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    showingAddItem = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加事项")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
            .padding(.horizontal)
            
            // 功能预览区域
            VStack(alignment: .leading, spacing: 20) {
                Text("添加事项心情后，你可以...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // 心情记录预览
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.gray.opacity(0.5))
                        Text("每日心情记录")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { value in
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .opacity(0.7)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                )
                .padding(.horizontal)
                
                // 趋势图表预览
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.gray.opacity(0.5))
                        Text("心情趋势分析")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 50))
                        path.addCurve(
                            to: CGPoint(x: 300, y: 30),
                            control1: CGPoint(x: 100, y: 0),
                            control2: CGPoint(x: 200, y: 60)
                        )
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(height: 80)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .opacity(0.7)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                )
                .padding(.horizontal)
                
                // 统计概览预览
                HStack(spacing: 20) {
                    // 连续记录预览
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange.opacity(0.3))
                            Text("连续记录")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        Text("-- 天")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 周平均预览
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue.opacity(0.3))
                            Text("周平均")
                                .font(.subheadline)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        Text("--")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .opacity(0.7)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                )
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    private func hasTodayMood(_ item: Item) -> Bool {
        let calendar = Calendar.current
        return item.moods.contains { calendar.isDate($0.date, inSameDayAs: Date()) }
    }
    
    private var userProfileHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(userVM.getGreeting())")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if userVM.isAuthenticated, let user = userVM.currentUser {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Text("点击登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                showingUserProfile = true
            } label: {
                if userVM.isAuthenticated, let user = userVM.currentUser,
                   let avatarUrl = user.avatarUrl {
                    AsyncImage(url: URL(fileURLWithPath: avatarUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func moodTrendCard(item: Item) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近期心情趋势")
                .font(.headline)
            
            WeekMoodChart(items: [item])
                .frame(height: 200)
                .padding(.vertical, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
    }
    
    private func statsOverviewCard(item: Item) -> some View {
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

// 周心情图表组件
struct WeekMoodChart: View {
    let items: [Item]
    
    var body: some View {
        Chart {
            let filteredData = weekData()
            
            // 首先绘制连线和区域
            ForEach(Array(filteredData.enumerated()), id: \.1.date) { index, data in
                if data.value > 0 {
                    // 绘制线段
                    LineMark(
                        x: .value("日期", data.date, unit: .day),
                        y: .value("心情", data.value)
                    )
                    .foregroundStyle(moodColor(data.value))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    // 绘制区域
                    AreaMark(
                        x: .value("日期", data.date, unit: .day),
                        y: .value("心情", data.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [
                                moodColor(data.value).opacity(0.2),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            
            // 然后绘制数据点
            ForEach(Array(filteredData.enumerated()), id: \.1.date) { index, data in
                if data.value > 0 {
                    // 有记录的点显示实心圆点
                    PointMark(
                        x: .value("日期", data.date, unit: .day),
                        y: .value("心情", data.value)
                    )
                    .foregroundStyle(moodColor(data.value))
                    .symbol {
                        Circle()
                            .fill(moodColor(data.value))
                            .frame(width: 10, height: 10)
                    }
                } else {
                    // 无记录的点显示空心圆圈
                    PointMark(
                        x: .value("日期", data.date, unit: .day),
                        y: .value("心情", 3) // 放在中间位置
                    )
                    .foregroundStyle(.clear)
                    .symbol {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            .frame(width: 8, height: 8)
                    }
                }
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
                    .font(.headline)
                Spacer()
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= currentValue ? "circle.fill" : "circle")
                        .font(.system(size: 24))
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .padding(.horizontal)
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

// 新增的辅助视图组件
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

struct MoodExtremeView: View {
    let title: String
    let date: Date
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Circle()
                        .fill(i <= value ? color : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(formatDate(date))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

struct TodayMoodSummaryView: View {
    let items: [Item]
    @State private var showingMoodInput = false
    @State private var selectedItemId: PersistentIdentifier?
    
    var todayMoods: [(Item, Mood)] {
        let calendar = Calendar.current
        return items.compactMap { item in
            if let mood = item.moods.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) }) {
                return (item, mood)
            }
            return nil
        }
    }
    
    var itemsWithoutMood: [Item] {
        let calendar = Calendar.current
        return items.filter { item in
            !item.moods.contains { calendar.isDate($0.date, inSameDayAs: Date()) }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 事项选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            selectedItemId = item.persistentModelID
                            showingMoodInput = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 24))
                                    .foregroundStyle(hasMoodToday(item) ? .blue : .gray)
                                Text(item.name)
                                    .font(.subheadline)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            
            // 今日心情列表
            ForEach(todayMoods, id: \.0.persistentModelID) { item, mood in
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        ItemIconView(icon: item.icon, size: 32, color: .blue)
                        Text(item.name)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button {
                            selectedItemId = item.persistentModelID
                            showingMoodInput = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        ForEach(1...5, id: \.self) { value in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(value <= mood.value ? moodColor(mood.value) : Color.gray.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                        }
                        
                        Spacer()
                        
                        Text(moodText(mood.value))
                            .font(.headline)
                            .foregroundColor(moodColor(mood.value))
                    }
                    
                    if !mood.note.isEmpty {
                        Text(mood.note)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 10)
                )
            }
            
            // 未记录心情的事项提示
            if !itemsWithoutMood.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("待记录事项")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ForEach(itemsWithoutMood) { item in
                        Button {
                            selectedItemId = item.persistentModelID
                            showingMoodInput = true
                        } label: {
                            HStack {
                                ItemIconView(icon: item.icon, color: .gray)
                                Text(item.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 5)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingMoodInput) {
            if let selectedItemId = selectedItemId,
               let selectedItem = items.first(where: { $0.persistentModelID == selectedItemId }) {
                QuickMoodInputView(preSelectedItem: selectedItem)
            }
        }
    }
    
    private func hasMoodToday(_ item: Item) -> Bool {
        let calendar = Calendar.current
        return item.moods.contains { calendar.isDate($0.date, inSameDayAs: Date()) }
    }
    
    private func moodText(_ value: Int) -> String {
        switch value {
        case 1: return "很差"
        case 2: return "较差"
        case 3: return "一般"
        case 4: return "不错"
        case 5: return "很好"
        default: return ""
        }
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
}

#Preview {
    OverviewView()
        .modelContainer(for: Item.self, inMemory: true)
}
