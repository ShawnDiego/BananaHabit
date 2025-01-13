import SwiftUI
import SwiftData
import Observation

struct ItemDetailView: View {
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
                        // 添加标题
                        Text(calendar.isDateInToday(currentDate) ? "今日心情" : formatDate(currentDate))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let mood = getMood(for: currentDate) {
                            MoodDisplayView(mood: mood)
                        } else if currentDate <= Date() {
                            // 如果是过去或今天的日期，显示输入界面
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
                
                // 修改后的未来预测部分
                VStack(alignment: .leading, spacing: 12) {
                    Text("心情预测")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    let prediction = MoodPrediction.predict(from: item.moods)
                    
                    if prediction.confidence == 0 {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.secondary)
                            Text("数据不足，无法预测")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(moodColor(5))
                                            .frame(width: 8, height: 8)
                                        Text("最高分")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("\(prediction.nextHighestDays)天后")
                                            .font(.title3)
                                            .foregroundColor(moodColor(5))
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(moodColor(1))
                                            .frame(width: 8, height: 8)
                                        Text("最低分")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("\(prediction.nextLowestDays)天后")
                                            .font(.title3)
                                            .foregroundColor(moodColor(1))
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("准确率")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(prediction.confidence * 100))%")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
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
    
    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().weekday())
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
