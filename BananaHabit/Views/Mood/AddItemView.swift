import SwiftUI
import SwiftData

// 这里应该包含Item模型，如果在项目中是另外导入的，请根据实际情况调整

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var itemName = ""
    @State private var selectedIcon = "😊"
    @State private var showingIconPicker = false
    @State private var isShowingEmoji = true  // 控制显示 emoji 还是 SF Symbols
    
    // 添加跟踪当前选中的图标类型
    @State private var selectedIconType: IconType = .emoji
    
    // 定义图标类型枚举
    enum IconType {
        case emoji
        case sfSymbol
    }
    
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
                            if selectedIconType == .emoji {
                                Text(selectedIcon)
                                    .font(.system(size: 30))
                            } else {
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue)
                            }
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
                        Picker("图标类型", selection: $selectedIconType) {
                            Text("表情符号").tag(IconType.emoji)
                            Text("系统图标").tag(IconType.sfSymbol)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .onChange(of: selectedIconType) { oldValue, newValue in
                            if newValue == .emoji && oldValue == .sfSymbol {
                                // 如果从系统图标切换到表情符号，设置默认表情
                                selectedIcon = "😊"
                            } else if newValue == .sfSymbol && oldValue == .emoji {
                                // 如果从表情符号切换到系统图标，设置默认系统图标
                                selectedIcon = "star.fill"
                            }
                        }
                        
                        if selectedIconType == .emoji {
                            // Emoji 列表
                            ScrollView {
                                ForEach(emojiCategories, id: \.0) { category in
                                    VStack(alignment: .leading) {
                                        Text(category.0)
                                            .font(.headline)
                                        // 对每一组 Emoji 使用单独的 LazyVGrid
                                        LazyVGrid(columns: [
                                            GridItem(.adaptive(minimum: 45))
                                        ], spacing: 10) {
                                            ForEach(category.1, id: \.self) { emoji in
                                                Button(action: {
                                                    // 仅更新当前选中的图标
                                                    selectedIcon = emoji
                                                    selectedIconType = .emoji
                                                    showingIconPicker = false
                                                }) {
                                                    Text(emoji)
                                                        .font(.system(size: 30))
                                                        .padding(8)
                                                        .background(
                                                            Circle()
                                                                .fill(selectedIcon == emoji ?
                                                                      Color.blue.opacity(0.2) : Color.clear)
                                                        )
                                                        .animation(.easeInOut, value: selectedIcon)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding()
                        } else {
                            // SF Symbols 列表
                            ScrollView {
                                ForEach(sfSymbolCategories, id: \.0) { category in
                                    Section(category.0) {
                                        LazyVGrid(columns: [
                                            GridItem(.adaptive(minimum: 45))
                                        ], spacing: 10) {
                                            ForEach(category.1, id: \.self) { symbol in
                                                Button(action: {
                                                    withAnimation {
                                                        selectedIcon = symbol
                                                        selectedIconType = .sfSymbol
                                                        showingIconPicker = false
                                                    }
                                                }) {
                                                    Image(systemName: symbol)
                                                        .font(.system(size: 24))
                                                        .foregroundColor(.blue)
                                                        .frame(width: 40, height: 40)
                                                        .background(
                                                            Circle()
                                                                .fill(selectedIcon == symbol ? 
                                                                    Color.blue.opacity(0.2) : 
                                                                    Color.clear)
                                                        )
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                            .padding()
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
        .onAppear {
            // 初始化时检查当前图标类型
            if let firstScalar = selectedIcon.unicodeScalars.first, firstScalar.properties.isEmoji {
                selectedIconType = .emoji
            } else {
                selectedIconType = .sfSymbol
            }
        }
    }
    
    // 检查是否是表情符号
    private func isEmojiIcon(_ icon: String) -> Bool {
        if let firstScalar = icon.unicodeScalars.first {
            return firstScalar.properties.isEmoji
        }
        return false
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
