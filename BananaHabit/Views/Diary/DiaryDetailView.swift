import SwiftUI
import PhotosUI
import SwiftData
import AVFoundation

// 用于表示日记内容的结构
fileprivate struct DiaryContent: Codable, Equatable {
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
    @State private var showingCameraAlert = false
    @State private var cameraError: String = ""
    @State private var showingDeleteAlert = false
    @State private var showingPasswordView = false
    @State private var isUnlocked = false
    @State private var isSettingPassword = false
    
    init(diary: Diary?) {
        self.existingDiary = diary
        let newDiary = diary ?? Diary()
        _diary = State(initialValue: newDiary)
        _selectedItem = State(initialValue: diary?.relatedItem)
        _selectedDate = State(initialValue: diary?.selectedDate)
        _title = State(initialValue: diary?.title ?? "")
        _isUnlocked = State(initialValue: !(diary?.isLocked ?? false))
        
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
        Group {
            if diary.isLocked && !isUnlocked {
                // 显示加密状态
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("此日记已加密")
                        .font(.headline)
                    
                    Button("输入密码查看") {
                        showingPasswordView = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
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
            }
        }
        .navigationTitle(title.isEmpty ? "新日记" : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if existingDiary != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if diary.isLocked {
                            Button(role: .destructive) {
                                diary.isLocked = false
                                diary.password = nil
                                isUnlocked = true
                            } label: {
                                Label("解除加密", systemImage: "lock.open")
                            }
                        } else {
                            Button {
                                isSettingPassword = true
                                showingPasswordView = true
                            } label: {
                                Label("加密日记", systemImage: "lock")
                            }
                        }
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("删除日记", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("删除日记", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let diary = existingDiary {
                    modelContext.delete(diary)
                    try? modelContext.save()
                    dismiss()
                }
            }
        } message: {
            Text("确定要删除这篇日记吗？此操作无法撤销。")
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate, isPresented: $showingDatePicker)
        }
        .sheet(isPresented: $showingItemPicker) {
            ItemPickerSheet(selectedItem: $selectedItem, items: items, isPresented: $showingItemPicker)
        }
        .sheet(isPresented: $showingPasswordView) {
            DiaryPasswordView(
                diary: $diary,
                isSettingPassword: isSettingPassword,
                onSuccess: {
                    isUnlocked = true
                }
            )
        }
        .onChange(of: diaryContent) { _, newContent in
            if let jsonData = try? JSONEncoder().encode(newContent),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                diary.content = jsonString
                saveDiary()
            }
        }
        .onChange(of: title) { _, _ in
            saveDiary()
        }
        .onChange(of: selectedItem) { _, _ in
            saveDiary()
        }
        .onChange(of: selectedDate) { _, _ in
            saveDiary()
        }
    }
    
    private func saveDiary() {
        // 检查日记内容是否为空
        let hasContent = diaryContent.items.contains { item in
            if item.type == .text {
                return !item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true // 图片类型的内容不为空
        }
        
        // 如果标题和内容都为空，不保存
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasContent {
            return
        }
        
        diary.modifiedAt = Date()
        diary.relatedItem = selectedItem
        diary.selectedDate = selectedDate
        if existingDiary == nil {
            modelContext.insert(diary)
        }
        try? modelContext.save()
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
    @State private var showingCamera = false
    @State private var showingFilePicker = false
    let items: [Item]
    @State private var showingCameraAlert = false
    @State private var cameraError: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题和内容区域
                VStack(alignment: .leading, spacing: 12) {
                    TextField("标题（可选）", text: $title)
                        .onChange(of: title) { _, newValue in
                            diary.title = newValue.isEmpty ? nil : newValue
                        }
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // 添加分隔线
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    RichTextEditor(content: $diaryContent, selectedRange: $selectedRange)
                        .frame(minHeight: UIScreen.main.bounds.height * 0.4)
                        .padding(.horizontal, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                )
                .padding(.horizontal, 20)
                
                // 关联信息区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("关联信息")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 12) {
                        ItemSelectionButton(
                            selectedItem: selectedItem,
                            items: items,
                            onSelect: {
                                showingItemPicker = true
                            }
                        )
                        .padding(.vertical, 4)
                        
                        if selectedItem != nil {
                            DateSelectionButton(selectedDate: selectedDate) {
                                showingDatePicker = true
                            }
                            .padding(.vertical, 4)
                        }
                        
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
                        
                        if selectedItem != nil && selectedDate == nil {
                            Text("请选择日期以完成关联")
                                .foregroundColor(.orange)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                    )
                }
                .padding(.horizontal, 20)
                
                // 时间信息区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("时间信息")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("创建时间：")
                                .foregroundColor(.secondary)
                            Text(diary.createdAt, style: .date)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text("修改时间：")
                                .foregroundColor(.secondary)
                            Text(diary.modifiedAt, style: .date)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemBackground))
                            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(
            Color(.secondarySystemBackground)
                .edgesIgnoringSafeArea(.all)
        )
        .photosPicker(isPresented: $showingPhotoPicker,
                     selection: $selectedPhotos,
                     matching: .images)
        .sheet(isPresented: $showingCamera) {
            CameraImagePicker(sourceType: .camera) { image in
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    insertImageAtCursor(imageData: imageData)
                }
            }
        }
        .alert("无法访问相机", isPresented: $showingCameraAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(cameraError)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image]
        ) { result in
            switch result {
            case .success(let url):
                if let imageData = try? Data(contentsOf: url) {
                    insertImageAtCursor(imageData: imageData)
                }
            case .failure:
                break
            }
        }
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
        .onChange(of: selectedItem) { _, newItem in
            if newItem != nil && selectedDate == nil {
                showingDatePicker = true
            }
        }
        .onAppear {
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenCamera"),
            object: nil,
            queue: .main
        ) { _ in
            checkCameraPermission()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenPhotoPicker"),
            object: nil,
            queue: .main
        ) { _ in
            showingPhotoPicker = true
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenFilePicker"),
            object: nil,
            queue: .main
        ) { _ in
            showingFilePicker = true
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        showCameraAlert(message: "您已拒绝访问相机，请在系统设置中允许访问相机")
                    }
                }
            }
        case .denied, .restricted:
            showCameraAlert(message: "无法访问相机，请在系统设置中允许访问相机")
        @unknown default:
            showCameraAlert(message: "相机访问出现未知错误")
        }
    }
    
    private func showCameraAlert(message: String) {
        cameraError = message
        showingCameraAlert = true
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self)
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

fileprivate struct RichTextEditor: UIViewRepresentable {
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
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        
        // 添加工具栏
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        let cameraButton = UIBarButtonItem(image: UIImage(systemName: "camera"), style: .plain, target: context.coordinator, action: #selector(Coordinator.openCamera))
        let photoButton = UIBarButtonItem(image: UIImage(systemName: "photo"), style: .plain, target: context.coordinator, action: #selector(Coordinator.openPhotoPicker))
        let fileButton = UIBarButtonItem(image: UIImage(systemName: "folder"), style: .plain, target: context.coordinator, action: #selector(Coordinator.openFilePicker))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [
            flexSpace,
            cameraButton,
            flexSpace,
            photoButton,
            flexSpace,
            fileButton,
            flexSpace
        ]
        textView.inputAccessoryView = toolbar
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let attributedString = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        
        var shouldUpdateText = true
        
        // 只有当内容真正发生变化时才更新
        if let currentText = textView.attributedText {
            let currentContent = currentText.string
            let newContent = content.items.filter { $0.type == .text }.map { $0.content }.joined()
            shouldUpdateText = currentContent != newContent
        }
        
        if shouldUpdateText {
            for item in content.items {
                switch item.type {
                case .text:
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.preferredFont(forTextStyle: .body).withSize(18),
                        .paragraphStyle: paragraphStyle,
                        .foregroundColor: UIColor.label
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
            
            let selectedRange = textView.selectedRange
            textView.attributedText = attributedString
            if selectedRange.location != NSNotFound {
                textView.selectedRange = selectedRange
            }
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        private var isUpdating = false
        private var lastSelectedRange: NSRange?
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        @objc func openCamera() {
            NotificationCenter.default.post(name: NSNotification.Name("OpenCamera"), object: nil)
        }
        
        @objc func openPhotoPicker() {
            NotificationCenter.default.post(name: NSNotification.Name("OpenPhotoPicker"), object: nil)
        }
        
        @objc func openFilePicker() {
            NotificationCenter.default.post(name: NSNotification.Name("OpenFilePicker"), object: nil)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating else { return }
            isUpdating = true
            
            let text = textView.attributedText.string
            
            // 更新或创建文本内容
            let textItems = parent.content.items.filter { $0.type == .image }
            let newTextItem = DiaryContent.ContentItem(type: .text, content: text)
            parent.content.items = [newTextItem] + textItems
            
            isUpdating = false
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            let newRange = textView.selectedRange
            guard newRange != lastSelectedRange else { return }
            lastSelectedRange = newRange
            
            DispatchQueue.main.async {
                self.parent.selectedRange = newRange
            }
        }
    }
}

// 相机拍照的 ImagePicker
struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true // 允许编辑（裁剪）
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // 优先使用编辑后的图片，如果没有则使用原图
            if let editedImage = info[.editedImage] as? UIImage {
                parent.onImagePicked(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.onImagePicked(originalImage)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

private struct ItemSelectionButton: View {
    let selectedItem: Item?
    let items: [Item]
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
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
            Group {
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("还没有心情事项")
                            .font(.headline)
                        Text("请先在主页添加心情事项")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
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

//struct DiaryPasswordView: View {
//    @Binding var diary: Diary
//    @Binding var isSettingPassword: Bool
//    let onSuccess: () -> Void
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("输入密码")
//                .font(.headline)
//            
//            TextField("密码", text: $diary.password)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//            
//            Button("确定") {
//                if let password = diary.password, !password.isEmpty {
//                    diary.isLocked = true
//                    isSettingPassword = false
//                    onSuccess()
//                }
//            }
//        }
//        .padding()
//    }
//} 
