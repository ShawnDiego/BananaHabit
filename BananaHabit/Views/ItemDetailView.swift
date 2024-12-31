import SwiftUI
import SwiftData
import Observation

struct ItemDetailView: View {
    @Bindable var item: Item
    @State private var currentDate: Date = Date()
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日历组件
                VStack {
                    CalendarView(selectedDate: $currentDate, item: item)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // 选中日期的心情
                VStack(alignment: .leading, spacing: 12) {
                    // 添加标题
                    Text(calendar.isDateInToday(currentDate) ? "今日心情" : formatDate(currentDate))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let mood = getMood(for: currentDate) {
                        MoodDisplayView(mood: mood)
                    } else if currentDate <= Date() {
                        // 如果是过去或今天的日期，显示输入界面
                        MoodInputView(item: item, date: currentDate)
                    } else {
                        Text("未来日期无法记录")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // 心情统计
                MoodStatsView(item: item)
            }
            .padding(.vertical)
        }
        .navigationTitle(item.name)
        .background(Color.gray.opacity(0.05))
    }
    
    private func getMood(for date: Date) -> Mood? {
        let startOfDay = calendar.startOfDay(for: date)
        return item.moods.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }
    }
    
    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().weekday())
    }
}
