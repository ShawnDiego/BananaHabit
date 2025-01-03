import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("事项信息") {
                    TextField("事项名称", text: $itemName)
                }
            }
            .navigationTitle("添加新事项")
//            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveItem()
                    }
                    .disabled(itemName.isEmpty)
                }
            }
        }
    }
    
    private func saveItem() {
        let newItem = Item(name: itemName)
        modelContext.insert(newItem)
        dismiss()
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
} 
