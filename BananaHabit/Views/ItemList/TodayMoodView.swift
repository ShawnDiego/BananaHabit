import SwiftUI
import SwiftData

struct TodayMoodView: View {
    @Bindable var item: Item
    private let calendar = Calendar.current
    @State private var shouldRefresh = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日心情")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let todayMood = getTodayMood() {
                MoodDisplayView(mood: todayMood)
            } else {
                MoodInputView(item: item, date: Date(), onSave: {
                    shouldRefresh = true
                })
            }
        }
        .onChange(of: shouldRefresh) { oldValue, newValue in
            if newValue {
                shouldRefresh = false
            }
        }
    }
    
    private func getTodayMood() -> Mood? {
        let today = calendar.startOfDay(for: Date())
        return item.moods.first { calendar.isDate($0.date, inSameDayAs: today) }
    }
}
