import SwiftUI
import SwiftData
import Observation

struct ItemDetailView: View {
    @Bindable var item: Item
    @State private var currentWeek: Date = Date()
    @State private var isShowingMonthView = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日历视图
                if isShowingMonthView {
                    MonthCalendarView(
                        currentDate: $currentWeek,
                        item: item,
                        isShowingMonthView: $isShowingMonthView
                    )
                    .padding()
                    .transition(.move(edge: .top))
                } else {
                    WeekCalendarView(
                        currentWeek: $currentWeek,
                        item: item
                    )
                    .padding()
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.height
                            }
                            .onEnded { value in
                                if value.translation.height > 50 {
                                    withAnimation {
                                        isShowingMonthView = true
                                    }
                                }
                                dragOffset = 0
                            }
                    )
                    .offset(y: max(0, dragOffset))
                    .transition(.move(edge: .bottom))
                }
                
                // 当天的心情设置
                if Calendar.current.isDateInToday(currentWeek) {
                    TodayMoodView(item: item)
                } else {
                    HistoryMoodView(item: item, date: currentWeek)
                }
            }
        }
        .navigationTitle(item.name)
    }
}

// 周历视图组件
struct WeekCalendarView: View {
    @Binding var currentWeek: Date
    @Bindable var item: Item
    
    var body: some View {
        VStack {
            // 月份显示
            HStack {
                Text(currentWeek.formatted(.dateTime.month(.wide).year()))
                    .font(.title2.bold())
                Spacer()
            }
            
            // 周历
            HStack {
                ForEach(weekDays, id: \.self) { date in
                    VStack {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption)
                        
                        Text(date.formatted(.dateTime.day()))
                            .font(.body)
                            .frame(width: 35, height: 35)
                            .background(isSelected(date) ? Color.blue : Color.clear)
                            .clipShape(Circle())
                            .foregroundColor(getDateColor(date))
                            .onTapGesture {
                                if !isFutureDate(date) {
                                    currentWeek = date
                                }
                            }
                        
                        // 显示心情指示器
                        if let mood = getMood(for: date), !isFutureDate(date) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                }
            }
            
            // 翻页按钮
            HStack {
                Button(action: previousWeek) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Button(action: nextWeek) {
                    Image(systemName: "chevron.right")
                }
                .disabled(isNextWeekDisabled())
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    // 获取当前周的所有日期
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeek))!
        return (0...6).map { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)!
        }
    }
    
    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: currentWeek)
    }
    
    private func isFutureDate(_ date: Date) -> Bool {
        date > Calendar.current.startOfDay(for: Date())
    }
    
    private func getDateColor(_ date: Date) -> Color {
        if isFutureDate(date) {
            return .gray
        }
        return isSelected(date) ? .white : .primary
    }
    
    private func isCurrentWeek() -> Bool {
        let calendar = Calendar.current
        let currentWeekNumber = calendar.component(.weekOfYear, from: Date())
        let selectedWeekNumber = calendar.component(.weekOfYear, from: currentWeek)
        let currentYear = calendar.component(.year, from: Date())
        let selectedYear = calendar.component(.year, from: currentWeek)
        
        return currentYear == selectedYear && currentWeekNumber <= selectedWeekNumber
    }
    
    private func getMood(for date: Date) -> Mood? {
        item.moods.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private func previousWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeek) {
            currentWeek = newDate
        }
    }
    
    private func nextWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeek),
           !isNextWeekDisabled() {
            currentWeek = newDate
        }
    }
    
    private func isNextWeekDisabled() -> Bool {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek)!
        let startOfNextWeek = calendar.startOfDay(for: nextWeek)
        return startOfNextWeek > calendar.startOfDay(for: Date())
    }
}

// 今日心情设置视图
struct TodayMoodView: View {
    @Bindable var item: Item
    @State private var note: String = ""
    
    var body: some View {
        VStack(spacing: 15) {
            Text("今日心情")
                .font(.headline)
            
            HStack(spacing: 20) {
                ForEach(1...5, id: \.self) { value in
                    VStack {
                        Image(systemName: value <= (getTodayMood()?.value ?? 0) ? "star.fill" : "star")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                updateMood(value: value)
                            }
                        Text("\(value)分")
                            .font(.caption)
                    }
                }
            }
            
            // 添加备注输入框
            TextField("添加备注...", text: $note)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: note) { oldValue, newValue in
                    if let mood = getTodayMood() {
                        mood.note = newValue
                    }
                }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            // 加载已有的备注
            note = getTodayMood()?.note ?? ""
        }
    }
    
    private func getTodayMood() -> Mood? {
        return item.moods.first { Calendar.current.isDateInToday($0.date) }
    }
    
    private func updateMood(value: Int) {
        if let existingMood = getTodayMood() {
            existingMood.value = value
        } else {
            let newMood = Mood(date: Date(), value: value, note: note, item: item)
            item.moods.append(newMood)
        }
    }
}

// 历史心情展示视图
struct HistoryMoodView: View {
    @Bindable var item: Item
    let date: Date
    @State private var note: String = ""
    
    var body: some View {
        VStack(spacing: 15) {
            Text(date.formatted(.dateTime.month().day().weekday()))
                .font(.headline)
            
            if let mood = getMood() {
                HStack(spacing: 20) {
                    ForEach(1...5, id: \.self) { value in
                        VStack {
                            Image(systemName: value <= mood.value ? "star.fill" : "star")
                                .font(.title)
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    updateMood(value: value)
                                }
                            Text("\(value)分")
                                .font(.caption)
                        }
                    }
                }
                
                // 添加备注输入框
                TextField("添加备注...", text: $note)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: note) { oldValue, newValue in
                        mood.note = newValue
                    }
                
                Text("记录于 \(mood.date.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                // 添加新的心情评分界面
                HStack(spacing: 20) {
                    ForEach(1...5, id: \.self) { value in
                        VStack {
                            Image(systemName: "star")
                                .font(.title)
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    updateMood(value: value)
                                }
                            Text("\(value)分")
                                .font(.caption)
                        }
                    }
                }
                
                // 添加备注输入框
                TextField("添加备注...", text: $note)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("点击星星添加心情")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .onAppear {
            // 加载已有的备注
            note = getMood()?.note ?? ""
        }
    }
    
    private func getMood() -> Mood? {
        return item.moods.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private func updateMood(value: Int) {
        if let existingMood = getMood() {
            existingMood.value = value
        } else {
            let newMood = Mood(date: date, value: value, note: note, item: item)
            item.moods.append(newMood)
        }
    }
}

// 月历视图组件
struct MonthCalendarView: View {
    @Binding var currentDate: Date
    @Bindable var item: Item
    @Binding var isShowingMonthView: Bool
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack {
            // 月份和年份显示
            HStack {
                Text(currentDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title2.bold())
                Spacer()
                Button(action: {
                    withAnimation {
                        isShowingMonthView = false
                    }
                }) {
                    Image(systemName: "chevron.up")
                }
            }
            
            // 星期标题
            HStack {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .frame(maxWidth: .infinity)
                        .font(.caption)
                }
            }
            
            // 日期网格
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, currentDate: currentDate, item: item)
                            .onTapGesture {
                                if !isFutureDate(date) {
                                    currentDate = date
                                    withAnimation {
                                        isShowingMonthView = false
                                    }
                                }
                            }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func daysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: currentDate)!
        let firstDay = interval.start
        
        // 获取月份第一天是星期几
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offsetDays = firstWeekday - calendar.firstWeekday
        
        // 填充前面的空白日期
        var days: [Date?] = Array(repeating: nil, count: offsetDays)
        
        // 添加月份中的所有日期
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentDate)!
        for day in daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        // 填充后面的空白日期，使总数是7的倍数
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func isFutureDate(_ date: Date) -> Bool {
        date > Calendar.current.startOfDay(for: Date())
    }
}

// 日期单元格组件
struct DayCell: View {
    let date: Date
    let currentDate: Date
    @Bindable var item: Item
    private let calendar = Calendar.current
    
    var body: some View {
        VStack {
            Text(date.formatted(.dateTime.day()))
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(isSelected ? Color.blue : Color.clear)
                .clipShape(Circle())
                .foregroundColor(dateColor)
            
            if let _ = getMood(), !isFutureDate {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: currentDate)
    }
    
    private var isFutureDate: Bool {
        date > calendar.startOfDay(for: Date())
    }
    
    private var dateColor: Color {
        if isFutureDate {
            return .gray
        }
        return isSelected ? .white : .primary
    }
    
    private func getMood() -> Mood? {
        item.moods.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
} 
