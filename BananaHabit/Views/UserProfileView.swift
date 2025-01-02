import SwiftUI
import PhotosUI
import AuthenticationServices

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userVM: UserViewModel
    @State private var showingDeleteAlert = false
    @State private var showingImagePicker = false
    @State private var showingAvatarActions = false
    @State private var showingNameEdit = false
    @State private var editingName = ""
    @State private var showingNotificationSettings = false
    
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
