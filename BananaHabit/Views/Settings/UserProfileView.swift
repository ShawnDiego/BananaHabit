import SwiftUI
import SwiftData
import PhotosUI
import AuthenticationServices
import UniformTypeIdentifiers

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userVM: UserViewModel
    @StateObject private var exportManager = DataExportManager.shared
    
    @State private var showingDeleteAlert = false
    @State private var showingImagePicker = false
    @State private var showingAvatarActions = false
    @State private var showingNameEdit = false
    @State private var editingName = ""
    @State private var showingNotificationSettings = false
    @State private var showingDocumentPicker = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            List {
                if let user = userVM.currentUser {
                    Section {
                        HStack {
                            Spacer()
                            Button {
                                showingAvatarActions = true
                            } label: {
                                AsyncImage(url: URL(fileURLWithPath: user.avatarUrl ?? "")) { image in
                                    image.resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        
                        HStack {
                            Spacer()
                            VStack {
                                Button {
                                    editingName = user.name
                                    showingNameEdit = true
                                } label: {
                                    Text(user.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                if let email = user.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    
                    Section {
                        Button("退出登录") {
                            userVM.currentUser = nil
                            userVM.isAuthenticated = false
                            dismiss()
                        }
                        .foregroundColor(.red)
                        
                        Button("注销账户") {
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    Section {
                        SignInWithAppleButton { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            switch result {
                            case .success(let authResults):
                                print("Authorization successful")
                            case .failure(let error):
                                print("Authorization failed: \(error.localizedDescription)")
                            }
                        }
                        .frame(height: 44)
                    }
                }
                
                Section {
                    Button {
                        showingNotificationSettings = true
                    } label: {
                        HStack {
                            Text("提醒设置")
                            Spacer()
                            Image(systemName: "bell")
                        }
                    }
                    
                    Button {
                        showingSettings = true
                    } label: {
                        HStack {
                            Text("安全设置")
                            Spacer()
                            Image(systemName: "lock.shield")
                        }
                    }
                }
                
                Section("数据管理") {
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Text("导出数据")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        HStack {
                            Text("导入数据")
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
            }
            .navigationTitle("个人资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("更改头像", isPresented: $showingAvatarActions, actions: {
                Button("从相册选择") {
                    showingImagePicker = true
                }
                if userVM.currentUser?.avatarUrl != nil {
                    Button("删除头像", role: .destructive) {
                        userVM.removeAvatar()
                    }
                }
                Button("取消", role: .cancel) { }
            })
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(completion: { image in
                    if let image = image {
                        userVM.updateAvatar(image)
                    }
                })
            }
            .alert("确认注销账户", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("确认注销", role: .destructive) {
                    userVM.currentUser = nil
                    userVM.isAuthenticated = false
                    dismiss()
                }
            } message: {
                Text("注销账户后，所有数据将被永久删除且无法恢复")
            }
            .sheet(isPresented: $showingNameEdit) {
                NavigationView {
                    Form {
                        Section("修改名字") {
                            TextField("你的名字", text: $editingName)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    .navigationTitle("修改名字")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingNameEdit = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                if !editingName.isEmpty {
                                    userVM.updateUserName(editingName)
                                }
                                showingNameEdit = false
                            }
                            .disabled(editingName.isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
            .alert("导入失败", isPresented: .init(
                get: { exportManager.importError != nil },
                set: { if !$0 { exportManager.importError = nil } }
            )) {
                Button("确定", role: .cancel) { }
            } message: {
                if let error = exportManager.importError {
                    Text(error)
                }
            }
            .alert("导入成功", isPresented: $exportManager.showSuccessAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("数据已成功导入")
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(types: [.json]) { url in
                    exportManager.importData(url, into: modelContext)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private func exportData() {
        do {
            // 获取所有数据类型
            let itemDescriptor = FetchDescriptor<Item>()
            let items = try modelContext.fetch(itemDescriptor)
            
            let diaryDescriptor = FetchDescriptor<Diary>()
            let diaries = try modelContext.fetch(diaryDescriptor)
            
            let recordDescriptor = FetchDescriptor<PomodoroRecord>()
            let records = try modelContext.fetch(recordDescriptor)
            
            // 导出所有数据
            if let url = exportManager.exportData(items, diaries, records) {
                exportURL = url
                showingShareSheet = true
            }
        } catch {
            exportManager.importError = error.localizedDescription
        }
    }
}

// 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else {
                parent.completion(nil)
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.parent.completion(image as? UIImage)
                    }
                }
            }
        }
    }
}

// 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // 开始访问安全作用域资源
            guard url.startAccessingSecurityScopedResource() else {
                print("无法访问文件：权限被拒绝")
                return
            }
            
            // 确保在完成时释放安全作用域资源
            defer { url.stopAccessingSecurityScopedResource() }
            
            // 使用文件协调器读取文件内容
            var error: NSError?
            let coordinator = NSFileCoordinator()
            var fileData: Data?
            
            coordinator.coordinate(readingItemAt: url, options: [], error: &error) { coordinatedURL in
                do {
                    fileData = try Data(contentsOf: coordinatedURL)
                } catch {
                    print("读取文件失败: \(error)")
                }
            }
            
            if let error = error {
                print("文件协调失败: \(error)")
                return
            }
            
            // 如果成功读取文件，创建临时文件
            if let data = fileData {
                do {
                    let tempDir = FileManager.default.temporaryDirectory
                    let tempUrl = tempDir.appendingPathComponent(url.lastPathComponent)
                    
                    // 如果临时文件已存在，先删除
                    if FileManager.default.fileExists(atPath: tempUrl.relativePath) {
                        try FileManager.default.removeItem(at: tempUrl)
                    }
                    
                    // 写入临时文件
                    try data.write(to: tempUrl)
                    
                    // 使用临时文件
                    DispatchQueue.main.async {
                        self.onPick(tempUrl)
                    }
                } catch {
                    print("创建临时文件失败: \(error)")
                }
            }
        }
    }
}

// 分享表单
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 
