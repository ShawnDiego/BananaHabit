import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName = ""
    @State private var selectedIcon = "😊"
    @State private var showingIconPicker = false
    @State private var isShowingEmoji = true  // 控制显示 emoji 还是 SF Symbols
    
    // 预设的表情符号列表
    let emojiCategories = [
        ("常用", ["😊", "😃", "🎯", "💪", "📚", "💻", "🎨", "🎵", "🏃", "🍎", "💤", "🌟"]),
        ("表情", ["😊", "😃", "😅", "😆", "😉", "😋", "😎", "🥳", "🤔", "😌", "😴", "🥰"]),
        ("活动", ["💪", "🏃", "🚶", "🧘", "🏋️", "🚴", "⛹️", "🤸", "🎯", "🎨", "🎵", "🎮"]),
        ("物品", ["📱", "💻", "📚", "✏️", "🎒", "💼", "🔋", "⏰", "📝", "🗒️", "📖", "🎯"]),
        ("饮食", ["🍎", "🥗", "🥪", "🥤", "🍵", "☕️", "🥑", "🥕", "🍚", "🥩", "🍖", "🥜"]),
        ("其他", ["🌟", "💫", "✨", "🌈", "🎈", "🎉", "🎊", "🎯", "🎲", "🔮", "🎪", "🎭"])
    ]
    
    // SF Symbols 分类
    let sfSymbolCategories = [
        ("常用", ["star.fill", "heart.fill", "book.fill", "pencil", "doc.fill", "folder.fill", "bell.fill", "gear", "person.fill", "house.fill"]),
        ("天气", ["sun.max.fill", "cloud.fill", "cloud.rain.fill", "cloud.sun.fill", "moon.fill", "wind", "snowflake", "umbrella.fill"]),
        ("运动", ["figure.run", "figure.walk", "bicycle", "figure.hiking", "figure.gymnastics", "figure.dance", "figure.basketball", "figure.tennis"]),
        ("设备", ["iphone", "desktopcomputer", "laptopcomputer", "keyboard", "printer.fill", "tv.fill", "headphones", "gamecontroller.fill"]),
        ("其他", ["leaf.fill", "flame.fill", "drop.fill", "bolt.fill", "crown.fill", "flag.fill", "tag.fill", "bookmark.fill"])
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("事项信息") {
                    HStack {
                        Text("图标")
                        Spacer()
                        Button(action: { showingIconPicker = true }) {
                            ItemIconView(icon: selectedIcon, size: 30)
                        }
                    }
                    
                    TextField("事项名称", text: $itemName)
                }
            }
            .navigationTitle("添加新事项")
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
            .sheet(isPresented: $showingIconPicker) {
                NavigationView {
                    VStack(spacing: 0) {
                        // 切换按钮
                        Picker("图标类型", selection: $isShowingEmoji) {
                            Text("表情符号").tag(true)
                            Text("系统图标").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        if isShowingEmoji {
                            // Emoji 列表
                            List {
                                ForEach(emojiCategories, id: \.0) { category in
                                    Section(category.0) {
                                        LazyVGrid(columns: [
                                            GridItem(.adaptive(minimum: 45))
                                        ], spacing: 10) {
                                            ForEach(category.1, id: \.self) { emoji in
                                                Button(action: {
                                                    selectedIcon = emoji
                                                    showingIconPicker = false
                                                }) {
                                                    Text(emoji)
                                                        .font(.system(size: 30))
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        } else {
                            // SF Symbols 列表
                            List {
                                ForEach(sfSymbolCategories, id: \.0) { category in
                                    Section(category.0) {
                                        LazyVGrid(columns: [
                                            GridItem(.adaptive(minimum: 45))
                                        ], spacing: 10) {
                                            ForEach(category.1, id: \.self) { symbol in
                                                Button(action: {
                                                    selectedIcon = symbol
                                                    showingIconPicker = false
                                                }) {
                                                    Image(systemName: symbol)
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.blue)
                                                        .frame(width: 40, height: 40)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("选择图标")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingIconPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private func saveItem() {
        let newItem = Item(name: itemName, icon: selectedIcon)
        modelContext.insert(newItem)
        dismiss()
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
} 
