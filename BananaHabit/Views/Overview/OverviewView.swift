import SwiftUI
import SwiftData
import Charts

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddItem = false
    @EnvironmentObject private var userVM: UserViewModel
    @State private var showingUserProfile = false
    @State private var showingMoodInput = false
    @State private var selectedItemId: PersistentIdentifier?
    
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
                    
                    // 事项选择器
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(items) { item in
                                Button {
                                    withAnimation {
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
                                    Text("添加事项")
                                        .font(.subheadline)
                                }
                                .frame(width: 80, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }
                    
                    if let item = selectedItem {
                        // 今日心情卡片
                        VStack {
                            if hasTodayMood(item) {
                                TodayMoodView(item: item)
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
                                            .fill(Color(.systemBackground))
                                            .shadow(color: .black.opacity(0.1), radius: 10)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            // 心情趋势图表
                            moodTrendCard(item: item)
                            
                            // 统计数据卡片
                            statsOverviewCard(item: item)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ItemIconView(icon: item.icon, color: .blue)
                        Text(item.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        Button {
                            selectedItemId = item.persistentModelID
                            showingMoodInput = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { value in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(value <= mood.value ? moodColor(mood.value) : Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        
                        Spacer()
                        
                        Text(moodText(mood.value))
                            .font(.subheadline)
                            .foregroundColor(moodColor(mood.value))
                    }
                    
                    if !mood.note.isEmpty {
                        Text(mood.note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
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
