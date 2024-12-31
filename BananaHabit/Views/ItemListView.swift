import SwiftUI
import SwiftData

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showingAddItem = false
    @State private var selectedItem: Item?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        Text(item.name)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("所有事项")
            .toolbar {
                Button(action: { showingAddItem = true }) {
                    Label("添加事项", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
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
} 