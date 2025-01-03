import SwiftUI

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Bindable var item: Item
    @State private var isExpanded = false
    @State private var currentMonth: Date
    
    private let calendar = Calendar.current
    private let weekDaySymbols = Calendar.current.veryShortWeekdaySymbols
    private let cellWidth: CGFloat = 40
    
    init(selectedDate: Binding<Date>, item: Item) {
        self._selectedDate = selectedDate
        self.item = item
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // 标题和导航
            HStack {
                Button(action: handlePreviousPeriod) {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                if isExpanded {
                    Text(currentMonth.formatted(.dateTime.year().month(.wide)))
                        .font(.title3.bold())
                } else {
                    Text(selectedDate.formatted(.dateTime.year().month(.wide)))
                        .font(.title3.bold())
                }
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                Spacer()
                
                Button(action: handleNextPeriod) {
                    Image(systemName: "chevron.right")
                }
                .disabled(isNextPeriodDisabled())
            }
            .padding(.horizontal)
            
            // 日历内容
            VStack(spacing: 15) {
                // 星期标题行
                HStack(spacing: 0) {
                    ForEach(weekDaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .frame(width: cellWidth)
                    }
                }
                
                // 日历主体
                calendarContent
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var calendarContent: some View {
        if isExpanded {
            // 月视图
            let dates = daysInMonth()
            VStack(spacing: 0) {
                ForEach(0..<(dates.count / 7), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            let index = row * 7 + column
                            if index < dates.count, let date = dates[index] {
                                DayCell(date: date, selectedDate: selectedDate, item: item)
                                    .frame(width: cellWidth, height: cellWidth)
                                    .onTapGesture {
                                        if !isFutureDate(date) {
                                            withAnimation {
                                                selectedDate = date
                                                isExpanded = false
                                            }
                                        }
                                    }
                            } else {
                                Color.clear
                                    .frame(width: cellWidth, height: cellWidth)
                            }
                        }
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            // 周视图
            HStack(spacing: 0) {
                ForEach(daysInWeek(), id: \.self) { date in
                    DayCell(date: date, selectedDate: selectedDate, item: item)
                        .frame(width: cellWidth, height: cellWidth)
                        .onTapGesture {
                            if !isFutureDate(date) {
                                withAnimation {
                                    selectedDate = date
                                }
                            }
                        }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
    
    private func daysInWeek() -> [Date] {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).map { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)!
        }
    }
    
    private func daysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: currentMonth)!
        let firstDay = interval.start
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offsetDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offsetDays)
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!
        for day in daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func handlePreviousPeriod() {
        withAnimation {
            if isExpanded {
                if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
                    currentMonth = newDate
                }
            } else {
                if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                    selectedDate = newDate
                }
            }
        }
    }
    
    private func handleNextPeriod() {
        withAnimation {
            if isExpanded {
                if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth),
                   !isNextPeriodDisabled() {
                    currentMonth = newDate
                }
            } else {
                if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate),
                   !isNextPeriodDisabled() {
                    selectedDate = newDate
                }
            }
        }
    }
    
    private func isNextPeriodDisabled() -> Bool {
        if isExpanded {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
            return nextMonth > Date()
        } else {
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate)!
            return nextWeek > Date()
        }
    }
    
    private func isFutureDate(_ date: Date) -> Bool {
        date > calendar.startOfDay(for: Date())
    }
}

struct DayCell: View {
    let date: Date
    let selectedDate: Date
    @Bindable var item: Item
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.blue : Color.clear)
                .clipShape(Circle())
                .foregroundColor(dateColor)
            
            if let mood = getMood(), !isFutureDate {
                Circle()
                    .fill(moodColor(mood.value))
                    .frame(width: 6, height: 6)
            } else {
                Color.clear
                    .frame(height: 6)
            }
        }
    }
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
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