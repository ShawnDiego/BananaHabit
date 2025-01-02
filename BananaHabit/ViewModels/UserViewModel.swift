import Foundation
import AuthenticationServices

class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    init() {
        loadUserState()
    }
    
    private func loadUserState() {
        if let userData = userDefaults.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    private func saveUserState() {
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: "currentUser")
        } else {
            userDefaults.removeObject(forKey: "currentUser")
        }
    }
    
    func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            return String(localized: "Good Morning")
        case 12..<14:
            return String(localized: "Good Afternoon")
        case 14..<18:
            return String(localized: "Good Afternoon")
        case 18..<22:
            return String(localized: "Good Evening")
        default:
            return String(localized: "Good Night")
        }
    }
    
    func updateAvatar(_ image: UIImage) {
        guard var user = currentUser else { return }
        
        // 获取应用的 Application Support 目录
        let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let avatarsDirectory = applicationSupportDirectory.appendingPathComponent("Avatars", isDirectory: true)
        
        // 创建头像目录（如果不存在）
        try? FileManager.default.createDirectory(at: avatarsDirectory, withIntermediateDirectories: true)
        
        // 生成唯一文件名
        let fileName = "\(user.id)_avatar.jpg"
        let fileURL = avatarsDirectory.appendingPathComponent(fileName)
        
        // 压缩图片并保存
        if let imageData = image.jpegData(compressionQuality: 0.7) {
            try? imageData.write(to: fileURL)
            user.avatarUrl = fileURL.path
            currentUser = user
            saveUserState()
        }
    }
    
    func removeAvatar() {
        guard var user = currentUser,
              let avatarPath = user.avatarUrl else { return }
        
        // 删除头像文件
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: avatarPath))
        
        user.avatarUrl = nil
        currentUser = user
        saveUserState()
    }
    
    private func getDocumentsDirectory() -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func updateUserName(_ newName: String) {
        if var user = currentUser {
            user.name = newName
            currentUser = user
            saveUserState()
        }
    }
} 