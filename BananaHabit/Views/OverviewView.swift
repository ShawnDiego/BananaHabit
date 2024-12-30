import SwiftUI
import SwiftData

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddItem = false
    
    var body: some View {
        NavigationView {
            List {
                Section("今日心情速记") {
                    if items.isEmpty {
                        Text("还没有添加任何事项")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(items) { item in
                            QuickMoodRow(item: item)
                        }
                    }
                }
                
                Section("统计概览") {
                    // 这里可以添加统计信息
                    Text("本周平均心情：4.2")
                    Text("连续记录：7天")
                }
            }
            .navigationTitle("概览")
            .toolbar {
                Button(action: { showingAddItem = true }) {
                    Label("添加事项", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
        }
    }
}

struct QuickMoodRow: View {
    @Bindable var item: Item
    
    var body: some View {
        HStack {
            Text(item.name)
            Spacer()
            ForEach(1...5, id: \.self) { value in
                Image(systemName: value <= (getTodayMood()?.value ?? 0) ? "star.fill" : "star")
                    .foregroundColor(.yellow)
                    .onTapGesture {
                        updateMood(value: value)
                    }
            }
        }
    }
    
    private func getTodayMood() -> Mood? {
        return item.moods.first { Calendar.current.isDateInToday($0.date) }
    }
    
    private func updateMood(value: Int) {
        if let existingMood = getTodayMood() {
            existingMood.value = value
        } else {
            let newMood = Mood(date: Date(), value: value, item: item)  // 更新这里
            item.moods.append(newMood)
        }
    }
}