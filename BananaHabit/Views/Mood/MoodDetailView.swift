import SwiftUI
import SwiftData
import Observation

// 需要在Xcode中添加MoodUtils的导入语句，例如:
// import BananaHabit

struct MoodDetailView: View {
    @Bindable var item: Item
    @State private var currentDate: Date = Date()
    @State private var shouldRefresh = false
    @State private var lastSavedDate: Date?  // 添加最后保存的日期
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 日历组件
                VStack {
                    CalendarView(selectedDate: $currentDate, item: item)
                    // 选中日期的心情
                    VStack(alignment: .leading, spacing: 12) {
                        // 格式化日期
                        let dateText = calendar.isDateInToday(currentDate) ? 
                            "今日心情" : 
                        MoodUtils.formatDate(currentDate) // 暂时使用本地方法直到修复导入
                        Text(dateText)
                            .font(.headline)
                        
                        // 获取心情
                        if let mood = getMood(for: currentDate) { // 暂时使用本地方法直到修复导入
                            MoodDisplayView(mood: mood)
                        } else if currentDate <= Date() {
                            //输入界面
                            MoodInputView(item: item, date: currentDate, onSave: {
                                lastSavedDate = currentDate
                            })
                        } else {
                            Text("未来日期无法记录")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal)
                
                // 心情统计
                MoodStatsView(item: item)
                
                // 未来预测部分
                MoodPredictionView(moods: item.moods)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(item.name)
        .background(Color.gray.opacity(0.05))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    EditItemView(item: item)
                } label: {
                    Image(systemName: "pencil.circle")
                }
            }
        }
        .onChange(of: currentDate) { oldValue, newValue in
            // 当切换日期时，如果不是最后保存的日期，重置状态
            if lastSavedDate == nil || !calendar.isDate(newValue, inSameDayAs: lastSavedDate!) {
                shouldRefresh = false
            }
        }
    }
    private func getMood(for date: Date) -> Mood? {
        let startOfDay = calendar.startOfDay(for: date)
        return item.moods.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }
    }

}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // 创建一个示例事项
    let item = Item(name: "工作", icon: "briefcase.fill")
    
    // 添加一些示例心情记录
    let calendar = Calendar.current
    let today = Date()
    
    // 添加今天的心情
    let todayMood = Mood(date: today, value: 4, note: "今天工作很顺利", item: item)
    item.moods.append(todayMood)
    
    // 添加昨天的心情
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let yesterdayMood = Mood(date: yesterday, value: 3, note: "一般般", item: item)
    item.moods.append(yesterdayMood)
    
    // 添加前天的心情
    let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
    let twoDaysAgoMood = Mood(date: twoDaysAgo, value: 5, note: "项目完成了！", item: item)
    item.moods.append(twoDaysAgoMood)
    
    // 将示例数据添加到容器中
    container.mainContext.insert(item)
    
    return NavigationStack {
        MoodDetailView(item: item)
    }
    .modelContainer(container)
}
