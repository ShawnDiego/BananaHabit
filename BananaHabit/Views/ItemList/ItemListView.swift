import SwiftUI
import SwiftData
import Charts

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddItem = false
    @State private var selectedItem: Item?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                NavigationStack {
                    List {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .navigationTitle("所有事项")
                    .toolbar {
                        Button(action: { showingAddItem = true }) {
                            Label("添加事项", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddItem) {
                    AddItemView()
                }
            } else {
                NavigationSplitView {
                    List(selection: $selectedItem) {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .navigationTitle("所有事项")
                    .toolbar {
                        Button(action: { showingAddItem = true }) {
                            Label("添加事项", systemImage: "plus")
                        }
                    }
                    .frame(minWidth: 200, maxWidth: 250)
                } detail: {
                    if let item = selectedItem ?? items.first {
                        ItemDetailView(item: item)
                    } else {
                        Text("请选择一个事项")
                            .foregroundColor(.gray)
                    }
                }
                .sheet(isPresented: $showingAddItem) {
                    AddItemView()
                }
            }
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
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
    
    private func itemRow(_ item: Item) -> some View {
        NavigationLink {
            ItemDetailView(item: item)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                
                // 最近十条数据的迷你图表
                MiniMoodChart(moods: getRecentMoods(item: item))
                    .frame(height: 50)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func getRecentMoods(item: Item) -> [Mood] {
        return Array(item.moods
            .sorted { $0.date > $1.date }
            .prefix(10)
            .reversed())
    }
}

// 添加迷你图表组件
struct MiniMoodChart: View {
    let moods: [Mood]
    
    var body: some View {
        Chart {
            ForEach(Array(moods.enumerated()), id: \.element.id) { index, mood in
                // 添加渐变阴影区域
                AreaMark(
                    x: .value("序号", index),
                    y: .value("心情", mood.value)
                )
                .foregroundStyle(
                    Gradient(colors: [moodColor(mood.value).opacity(0.2), .clear])
                )
                
                // 线条
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
