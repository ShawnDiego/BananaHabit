import SwiftUI
import PhotosUI
import SwiftData

// 用于表示日记内容的结构
private struct DiaryContent: Codable, Equatable {
    enum ContentType: String, Codable, Equatable {
        case text
        case image
    }
    
    struct ContentItem: Identifiable, Codable, Equatable {
        let id: UUID
        let type: ContentType
        var content: String // 文本内容或图片数据的Base64编码
        
        init(id: UUID = UUID(), type: ContentType, content: String) {
            self.id = id
            self.type = type
            self.content = content
        }
        
        static func == (lhs: ContentItem, rhs: ContentItem) -> Bool {
            lhs.id == rhs.id && lhs.type == rhs.type && lhs.content == rhs.content
        }
    }
    
    var items: [ContentItem]
    
    init(items: [ContentItem] = []) {
        self.items = items.isEmpty ? [ContentItem(type: .text, content: "")] : items
    }
    
    static func == (lhs: DiaryContent, rhs: DiaryContent) -> Bool {
        lhs.items == rhs.items
    }
}

struct DiaryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    private let existingDiary: Diary?
    @State private var diary: Diary
    @State private var selectedItem: Item?
    @State private var selectedDate: Date?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingItemPicker = false
    @State private var showingDatePicker = false
    @State private var title: String = ""
    @State private var diaryContent: DiaryContent
    @State private var showingPhotoPicker = false
    
    init(diary: Diary?) {
        self.existingDiary = diary
        let newDiary = diary ?? Diary()
        _diary = State(initialValue: newDiary)
        _selectedItem = State(initialValue: diary?.relatedItem)
        _selectedDate = State(initialValue: diary?.selectedDate)
        _title = State(initialValue: diary?.title ?? "")
        
        // 初始化日记内容
        if let contentData = newDiary.content.data(using: .utf8),
           let content = try? JSONDecoder().decode(DiaryContent.self, from: contentData) {
            _diaryContent = State(initialValue: content)
        } else {
            _diaryContent = State(initialValue: DiaryContent(items: [
                DiaryContent.ContentItem(type: .text, content: newDiary.content)
            ]))
        }
    }
    
    var body: some View {
        NavigationView {
            DiaryFormView(
                diary: $diary,
                diaryContent: $diaryContent,
                title: $title,
                selectedItem: $selectedItem,
                selectedDate: $selectedDate,
                selectedPhotos: $selectedPhotos,
                showingItemPicker: $showingItemPicker,
                showingDatePicker: $showingDatePicker,
                showingPhotoPicker: $showingPhotoPicker,
                items: items
            )
            .navigationTitle(title.isEmpty ? "新日记" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveDiary() }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate, isPresented: $showingDatePicker)
            }
            .sheet(isPresented: $showingItemPicker) {
                ItemPickerSheet(selectedItem: $selectedItem, items: items, isPresented: $showingItemPicker)
            }
        }
        .onChange(of: diaryContent) { _, newContent in
            if let jsonData = try? JSONEncoder().encode(newContent),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                diary.content = jsonString
            }
        }
    }
    
    private func saveDiary() {
        diary.modifiedAt = Date()
        diary.relatedItem = selectedItem
        diary.selectedDate = selectedDate
        if existingDiary == nil {
            modelContext.insert(diary)
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct DiaryFormView: View {
    @Binding var diary: Diary
    @Binding var diaryContent: DiaryContent
    @Binding var title: String
    @Binding var selectedItem: Item?
    @Binding var selectedDate: Date?
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var showingItemPicker: Bool
    @Binding var showingDatePicker: Bool
    @Binding var showingPhotoPicker: Bool
    @State private var selectedRange: NSRange?
    let items: [Item]
    
    var body: some View {
        ZStack {
            Form {
                Section {
                    TextField("标题（可选）", text: $title)
                        .onChange(of: title) { _, newValue in
                            diary.title = newValue.isEmpty ? nil : newValue
                        }
                        .font(.title3)
                        .padding(.vertical, 4)
                    
                    RichTextEditor(content: $diaryContent, selectedRange: $selectedRange)
                        .frame(minHeight: 200)
                }
                
                Section {
                    ItemSelectionButton(selectedItem: selectedItem, items: items) {
                        showingItemPicker = true
                    }
                    .padding(.vertical, 4)
                    
                    DateSelectionButton(selectedDate: selectedDate) {
                        showingDatePicker = true
                    }
                    .padding(.vertical, 4)
                    
                    if let item = selectedItem, let date = selectedDate {
                        if let mood = getMood(for: item, on: date) {
                            MoodDisplayView(mood: mood)
                                .padding(.vertical, 8)
                        } else {
                            if !Calendar.current.isDateInToday(date) && date > Date() {
                                Text("未来日期无法记录心情")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                MoodInputView(item: item, date: date, onSave: {})
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                } header: {
                    Text("关联信息")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .textCase(nil)
                }
                
                Section {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("创建时间：")
                            .foregroundColor(.secondary)
                        Text(diary.createdAt, style: .date)
                            .foregroundColor(.primary)
                    }
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                        Text("修改时间：")
                            .foregroundColor(.secondary)
                        Text(diary.modifiedAt, style: .date)
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("时间信息")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .textCase(nil)
                }
            }
            
            // 悬浮按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingButton {
                        showingPhotoPicker = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker,
                     selection: $selectedPhotos,
                     matching: .images)
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        insertImageAtCursor(imageData: data)
                    }
                }
                selectedPhotos.removeAll()
            }
        }
    }
    
    private func getMood(for item: Item, on date: Date) -> Mood? {
        let calendar = Calendar.current
        return item.moods.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func insertImageAtCursor(imageData: Data) {
        let base64String = imageData.base64EncodedString()
        let imageItem = DiaryContent.ContentItem(type: .image, content: base64String)
        
        if let range = selectedRange {
            // 在光标位置插入图片
            let index = diaryContent.items.firstIndex { item in
                if item.type == .text {
                    let length = item.content.count
                    return range.location <= length
                }
                return false
            } ?? diaryContent.items.endIndex
            
            if index < diaryContent.items.endIndex {
                let item = diaryContent.items[index]
                if item.type == .text {
                    let content = item.content
                    let prefix = String(content.prefix(range.location))
                    let suffix = String(content.dropFirst(range.location))
                    
                    diaryContent.items.remove(at: index)
                    if !prefix.isEmpty {
                        diaryContent.items.insert(DiaryContent.ContentItem(type: .text, content: prefix), at: index)
                    }
                    diaryContent.items.insert(imageItem, at: index + (prefix.isEmpty ? 0 : 1))
                    if !suffix.isEmpty {
                        diaryContent.items.insert(DiaryContent.ContentItem(type: .text, content: suffix), at: index + (prefix.isEmpty ? 1 : 2))
                    }
                }
            } else {
                diaryContent.items.append(imageItem)
            }
        } else {
            // 如果没有选中位置，添加到末尾
            diaryContent.items.append(imageItem)
        }
    }
}

private struct FloatingButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)
                .background(Color.accentColor.clipShape(Circle()))
                .shadow(radius: 4)
        }
    }
}

private struct RichTextEditor: UIViewRepresentable {
    @Binding var content: DiaryContent
    @Binding var selectedRange: NSRange?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body).withSize(18)
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        updateUIView(textView, context: context)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let attributedString = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        
        for item in content.items {
            switch item.type {
            case .text:
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.preferredFont(forTextStyle: .body).withSize(18),
                    .paragraphStyle: paragraphStyle
                ]
                let textString = NSAttributedString(string: item.content, attributes: attributes)
                attributedString.append(textString)
            case .image:
                if let imageData = Data(base64Encoded: item.content),
                   let image = UIImage(data: imageData) {
                    let maxWidth = textView.frame.width - 20
                    let aspectRatio = image.size.width / image.size.height
                    let targetSize = CGSize(width: min(maxWidth, image.size.width),
                                          height: min(maxWidth / aspectRatio, image.size.height))
                    
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    attachment.bounds = CGRect(origin: .zero, size: targetSize)
                    attributedString.append(NSAttributedString(attachment: attachment))
                    attributedString.append(NSAttributedString(string: "\n"))
                }
            }
        }
        
        textView.attributedText = attributedString
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // 更新内容
            let text = textView.attributedText.string
            
            // 找到最后一个文本项的索引
            let lastTextItemIndex = parent.content.items.lastIndex { $0.type == .text }
            
            if let index = lastTextItemIndex {
                // 更新现有的文本项
                parent.content.items[index].content = text
            } else {
                // 如果没有文本项，添加一个新的
                parent.content.items.append(DiaryContent.ContentItem(type: .text, content: text))
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}

private struct ItemSelectionButton: View {
    let selectedItem: Item?
    let items: [Item]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.accentColor)
                Text("关联心情事项")
                    .foregroundColor(.primary)
                Spacer()
                if let item = selectedItem {
                    HStack(spacing: 8) {
                        ItemIconView(icon: item.icon)
                        Text(item.name)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct DateSelectionButton: View {
    let selectedDate: Date?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                Text("选择日期")
                    .foregroundColor(.primary)
                Spacer()
                if let date = selectedDate {
                    Text(date, style: .date)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            DatePicker("选择日期",
                      selection: Binding(
                        get: { selectedDate ?? Date() },
                        set: { selectedDate = $0 }
                      ),
                      displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ItemPickerSheet: View {
    @Binding var selectedItem: Item?
    let items: [Item]
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    Button(action: {
                        selectedItem = item
                        isPresented = false
                    }) {
                        HStack {
                            ItemIconView2(item: item)
                            Text(item.name)
                            Spacer()
                            if selectedItem?.id == item.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择心情事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ItemIconView2: View {
    let item: Item
    
    var body: some View {
        Image(systemName: item.icon)
            .foregroundColor(.accentColor)
            .frame(width: 24, height: 24)
    }
}

struct ImageEditorView: View {
    let image: UIImage
    @Binding var scale: CGFloat
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var offset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var currentAmount: CGFloat = 0
    @State private var showingCropView = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(currentScale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { amount in
                                    currentScale = scale * (1 + amount - currentAmount)
                                    currentAmount = amount
                                }
                                .onEnded { amount in
                                    scale = currentScale
                                    currentAmount = 0
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                }
                                .onEnded { value in
                                    offset = .zero
                                }
                        )
                    
                    // 底部工具栏
                    HStack {
                        Button {
                            showingCropView = true
                        } label: {
                            VStack {
                                Image(systemName: "crop")
                                Text("裁剪")
                            }
                        }
                        Spacer()
                        Slider(value: $currentScale, in: 0.5...3.0)
                            .frame(width: 200)
                        Spacer()
                        Button {
                            currentScale = 1.0
                            offset = .zero
                        } label: {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("重置")
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("编辑图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // 保存编辑后的图片
                        let renderer = ImageRenderer(content: 
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(currentScale)
                        )
                        if let editedImage = renderer.uiImage {
                            onSave(editedImage)
                        }
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCropView) {
            // 这里可以添加裁剪视图的实现
            // 由于 SwiftUI 没有内置的图片裁剪功能，我们可能需要使用 UIKit 的 UIImagePickerController
            Text("裁剪功能开发中")
                .presentationDetents([.medium])
        }
    }
} 
