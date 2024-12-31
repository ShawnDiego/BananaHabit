import SwiftUI
import SwiftData

struct HistoryMoodView: View {
    @Bindable var item: Item
    let date: Date
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史心情")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let mood = getMood() {
                MoodDisplayView(mood: mood)
            } else {
                Text("暂无记录")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func getMood() -> Mood? {
        item.moods.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
} 
