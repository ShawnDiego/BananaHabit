import SwiftUI
import SwiftData
import Charts

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.sortOrder) private var items: [Item]
    @State private var showingAddItem = false
    @State private var selectedItem: Item?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
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
            } else {
                NavigationSplitView {
                    List(selection: $selectedItem) {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                        .onDelete(perform: deleteItems)
                        .onMove { from, to in
                            moveItems(from: from, to: to)
                        }
                    }
                    .navigationTitle("所有事项")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            EditButton()
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showingAddItem = true }) {
                                Label("添加事项", systemImage: "plus")
                            }
                        }
                    }
                    .frame(minWidth: 200, maxWidth: 250)
                } detail: {
                    if let item = selectedItem ?? items.first {
                        ItemDetailView(item: item)
                    }
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
        .background(Color(.systemGroupedBackground))
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
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        // 更新所有受影响项目的sortOrder
        var updatedItems = items
        updatedItems.move(fromOffsets: source, toOffset: destination)
        
        for (index, item) in updatedItems.enumerated() {
            item.sortOrder = index
        }
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
