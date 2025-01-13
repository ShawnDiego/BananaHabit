import SwiftUI
import SwiftData

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: Item
    let onIconSelected: (String) -> Void
    
    @State private var isShowingEmoji = true
    
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
            VStack(spacing: 0) {
                Picker("图标类型", selection: $isShowingEmoji) {
                    Text("表情符号").tag(true)
                    Text("系统图标").tag(false)
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(isShowingEmoji ? emojiCategories : sfSymbolCategories, id: \.0) { category in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(category.0)
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: 45))
                                ], spacing: 10) {
                                    ForEach(category.1, id: \.self) { icon in
                                        Button {
                                            selectIcon(icon)
                                        } label: {
                                            if isShowingEmoji {
                                                Text(icon)
                                                    .font(.system(size: 30))
                                            } else {
                                                Image(systemName: icon)
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .frame(width: 45, height: 45)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(item.icon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func selectIcon(_ icon: String) {
        item.icon = icon
        try? modelContext.save()
        onIconSelected(icon)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Item.self, configurations: config)
    let item = Item(name: "测试事项", icon: "star.fill")
    
    return IconPickerView(item: item) { _ in }
        .modelContainer(container)
} 