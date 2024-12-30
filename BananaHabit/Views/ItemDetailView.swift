import SwiftUI
import SwiftData
import Observation

struct ItemDetailView: View {
    @Bindable var item: Item
    @State private var currentWeek: Date = Date()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 周历视图
                WeekCalendarView(
                    currentWeek: $currentWeek,
                    item: item
                )
                .padding()
                
                // 当天的心情设置
                if Calendar.current.isDateInToday(currentWeek) {
                    TodayMoodView(item: item)
                } else {
                    // 显示历史心情
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
                            .foregroundColor(isSelected(date) ? .white : .primary)
                            .onTapGesture {
                                currentWeek = date
                            }
                        
                        // 显示心情指示器
                        if let mood = getMood(for: date) {
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
    
    private func getMood(for date: Date) -> Mood? {
        item.moods.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private func previousWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeek) {
            currentWeek = newDate
        }
    }
    
    private func nextWeek() {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeek) {
            currentWeek = newDate
        }
    }
}

// 今日心情设置视图
struct TodayMoodView: View {
    @Bindable var item: Item
    
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
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func getTodayMood() -> Mood? {
        return item.moods.first { Calendar.current.isDateInToday($0.date) }
    }
    
    private func updateMood(value: Int) {
        if let existingMood = getTodayMood() {
            existingMood.value = value
        } else {
            let newMood = Mood(date: Date(), value: value, item: item)
            item.moods.append(newMood)
        }
    }
}

// 历史心情展示视图
struct HistoryMoodView: View {
    @Bindable var item: Item
    let date: Date
    
    var body: some View {
        VStack(spacing: 15) {
            Text(date.formatted(.dateTime.month().day().weekday()))
                .font(.headline)
            
            if let mood = getMood() {
                HStack {
                    ForEach(1...5, id: \.self) { value in
                        Image(systemName: value <= mood.value ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                    }
                }
                Text("记录于 \(mood.date.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text("暂无记录")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func getMood() -> Mood? {
        return item.moods.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
} 
