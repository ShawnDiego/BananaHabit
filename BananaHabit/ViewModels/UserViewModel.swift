import Foundation
import AuthenticationServices

class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    private let fileManager = FileManager.default
    
    init() {
        loadUserState()
    }
    
    private func loadUserState() {
        let userDefaults = UserDefaults.standard
        // 首先检查认证状态
        isAuthenticated = userDefaults.bool(forKey: "IsAuthenticated")
        
        // 如果已认证，加载用户数据
        if isAuthenticated,
           let userData = userDefaults.dictionary(forKey: "CurrentUser"),
           let id = userData["id"] as? String,
           let name = userData["name"] as? String {
            
            var user = User(id: id, name: name)
            user.email = userData["email"] as? String
            user.avatarUrl = userData["avatarUrl"] as? String
            
            DispatchQueue.main.async {
                self.currentUser = user
            }
        }
    }
    
    func saveUserState() {
        guard let user = currentUser else { return }
        
        let userDefaults = UserDefaults.standard
        let userData: [String: Any] = [
            "id": user.id,
            "name": user.name,
            "email": user.email ?? "",
            "avatarUrl": user.avatarUrl ?? ""
        ]
        
        userDefaults.set(userData, forKey: "CurrentUser")
        userDefaults.set(true, forKey: "IsAuthenticated")
        userDefaults.synchronize()
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "CurrentUser")
        UserDefaults.standard.set(false, forKey: "IsAuthenticated")
        UserDefaults.standard.synchronize()
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
