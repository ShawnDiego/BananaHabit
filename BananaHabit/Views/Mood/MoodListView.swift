import SwiftUI
import SwiftData
import Charts

struct MoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.sortOrder) private var items: [Item]
    @State private var showingAddItem = false
    @State private var selectedItem: Item?
    @State private var showingDeleteAlert = false
    @State private var indexSetToDelete: IndexSet?
    
    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                        .onDelete(perform: deleteItems)
                        .onMove { from, to in
                            moveItems(from: from, to: to)
                        }
                    }
                }
            }
            .navigationTitle("所有事项")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !items.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Label("添加事项", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView()
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {
                indexSetToDelete = nil
            }
            Button("删除", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("确定要删除所选事项吗？此操作将同时删除该事项的所有心情记录。")
        }
        .onAppear {
            if selectedItem == nil && !items.isEmpty {
                selectedItem = items.first
            }
        }
        .onChange(of: items) { oldValue, newValue in
            if selectedItem == nil && !newValue.isEmpty {
                selectedItem = newValue.first
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.text.square")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.8))
            
            VStack(spacing: 8) {
                Text("还没有任何事项")
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("添加一个想要记录心情的事项吧")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button {
                showingAddItem = true
            } label: {
                Label("添加第一个事项", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
    
    private func deleteItems(offsets: IndexSet) {
        indexSetToDelete = offsets
        showingDeleteAlert = true
    }
    
    private func confirmDelete() {
        guard let indexSet = indexSetToDelete else { return }
        
        withAnimation {
            for index in indexSet {
                modelContext.delete(items[index])
            }
        }
        indexSetToDelete = nil
    }
    
    private func itemRow(_ item: Item) -> some View {
        NavigationLink(destination: MoodDetailView(item: item)) {
            HStack {
                ItemIconView(icon: item.icon, size: 20, color: .blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    
                    let recentMoods = getRecentSevenDaysMoods(item: item)
                    if recentMoods.isEmpty {
                        Text("暂无近七天数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: 30, alignment: .leading)
                    } else {
                        MiniMoodChart(moods: recentMoods)
                            .frame(height: 30)
                    }
                }
                
                Spacer()
            }
            .frame(height: 60)
            .contentShape(Rectangle())
        }
    }
    
    private func getRecentSevenDaysMoods(item: Item) -> [Mood] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return item.moods
            .filter { $0.date >= sevenDaysAgo }
            .sorted { $0.date < $1.date }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        // 更新所有受影响项目的sortOrder
        var updatedItems = items
        updatedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in updatedItems.enumerated() {
            item.sortOrder = index
        }
    }
}

struct MiniMoodChart: View {
    let moods: [Mood]
    
    var body: some View {
        if moods.isEmpty {
            Text("暂无近七天数据")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Chart {
                ForEach(Array(moods.enumerated()), id: \.offset) { index, mood in
                    AreaMark(
                        x: .value("序号", index),
                        y: .value("心情", mood.value)
                    )
                    .foregroundStyle(
                        Gradient(colors: [moodColor(mood.value).opacity(0.2), .clear])
                    )
                    
                    LineMark(
                        x: .value("序号", index),
                        y: .value("心情", mood.value)
                    )
                    .foregroundStyle(moodColor(mood.value))
                    .symbol {
                        Circle()
                            .fill(moodColor(mood.value))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: 0...5)
            .chartYAxis(.hidden)
        }
    }
    
    private func moodColor(_ value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Item.self, configurations: config)
    
    // 创建示例数据
    let item1 = Item(name: "工作", icon: "briefcase.fill")
    item1.sortOrder = 0
    
    let item2 = Item(name: "健身", icon: "figure.run")
    item2.sortOrder = 1
    
    let item3 = Item(name: "学习", icon: "book.fill")
    item3.sortOrder = 2
    
    let item4 = Item(name: "娱乐", icon: "gamecontroller.fill")
    item4.sortOrder = 3
    
    // 添加近7天的心情数据
    let calendar = Calendar.current
    let today = Date()
    
    // 为item1添加近7天数据
    let dates1 = [0, -1, -2, -3, -4, -5, -6]
    let values1 = [4, 3, 5, 4, 3, 2, 4]
    
    for (index, dayOffset) in dates1.enumerated() {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        let mood = Mood(date: date, value: values1[index], note: "工作日记 \(abs(dayOffset))", item: item1)
        item1.moods.append(mood)
    }
    
    // 为item2添加部分数据
    let dates2 = [0, -2, -4, -6]
    let values2 = [5, 4, 5, 4]
    
    for (index, dayOffset) in dates2.enumerated() {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        let mood = Mood(date: date, value: values2[index], note: "锻炼感受 \(abs(dayOffset))", item: item2)
        item2.moods.append(mood)
    }
    
    // 为item3添加少量数据
    let dates3 = [-1, -3, -5]
    let values3 = [3, 4, 2]
    
    for (index, dayOffset) in dates3.enumerated() {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        let mood = Mood(date: date, value: values3[index], note: "学习笔记 \(abs(dayOffset))", item: item3)
        item3.moods.append(mood)
    }
    
    container.mainContext.insert(item1)
    container.mainContext.insert(item2)
    container.mainContext.insert(item3)
    container.mainContext.insert(item4) // 空列表项
    
    return MoodListView()
        .modelContainer(container)
}
