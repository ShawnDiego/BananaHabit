import SwiftUI
import SwiftData

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    
    @State private var itemName: String
    @State private var showingIconPicker = false
    @State private var showingDeleteAlert = false
    
    init(item: Item) {
        self.item = item
        _itemName = State(initialValue: item.name)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("事项信息") {
                    HStack {
                        Text("图标")
                        Spacer()
                        Button(action: { showingIconPicker = true }) {
                            ItemIconView(icon: item.icon, size: 30)
                        }
                    }
                    
                    TextField("事项名称", text: $itemName)
                        .onChange(of: itemName) { oldValue, newValue in
                            // 当名称改变时自动保存
                            item.name = newValue
                            try? modelContext.save()
                        }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除事项")
                        }
                    }
                }
            }
            .navigationTitle("编辑事项")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(item: item) { newIcon in
                    try? modelContext.save()
                }
            }
            .alert("删除事项", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("确定要删除这个事项吗？所有相关的心情记录也会被删除。")
            }
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
} 
