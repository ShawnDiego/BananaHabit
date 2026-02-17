import UserNotifications
import SwiftUI
import UIKit

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    @Published var isNotificationsEnabled = false
    @Published var apnsDeviceToken: String?
    @Published var remoteRegistrationMessage = "未开始远程推送注册"
    @Published var pushServerBaseURL: String
    
    private let pushServerBaseURLKey = "pushServerBaseURL"
    private let lastUploadedTokenKey = "lastUploadedApnsToken"
    private let lastUploadedServerURLKey = "lastUploadedPushServerURL"
    private let defaultPushServerBaseURL = "http://127.0.0.1:8787"
    
    init() {
        let savedURL = UserDefaults.standard.string(forKey: pushServerBaseURLKey) ?? defaultPushServerBaseURL
        pushServerBaseURL = savedURL
        refreshAuthorizationStatus()
    }
    
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
                if self.isNotificationsEnabled {
                    self.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = granted
                if let error {
                    self.remoteRegistrationMessage = "通知授权失败: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                if granted {
                    self.registerForRemoteNotifications()
                } else {
                    self.remoteRegistrationMessage = "用户未授予通知权限"
                }
                completion(granted)
            }
        }
    }
    
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            self.remoteRegistrationMessage = "正在向 APNs 注册设备..."
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func updatePushServerBaseURL(_ urlString: String) {
        let normalized = normalizedServerURL(from: urlString)
        pushServerBaseURL = normalized
        UserDefaults.standard.set(normalized, forKey: pushServerBaseURLKey)
        
        if let apnsDeviceToken {
            uploadDeviceTokenIfNeeded(apnsDeviceToken, forceUpload: true)
        }
    }
    
    func updateRemoteDeviceToken(_ deviceTokenData: Data) {
        let token = deviceTokenData.map { String(format: "%02x", $0) }.joined()
        
        DispatchQueue.main.async {
            self.apnsDeviceToken = token
            self.remoteRegistrationMessage = "APNs 注册成功，正在同步设备 Token..."
        }
        
        uploadDeviceTokenIfNeeded(token)
    }
    
    func handleRemoteRegistrationFailure(_ error: Error) {
        DispatchQueue.main.async {
            self.remoteRegistrationMessage = "APNs 注册失败: \(error.localizedDescription)"
        }
    }
    
    func handleIncomingRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        print("收到远程推送: \(userInfo)")
    }
    
    func scheduleDaily(at time: Date) {
        // 取消之前的通知
        cancelAllNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = "记录今天的心情"
        content.body = "花一点时间记录下今天的心情吧"
        content.sound = .default
        
        // 获取时间组件
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        // 创建触发器
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: "dailyMoodReminder",
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知设置失败: \(error)")
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func isNotificationScheduled(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(!requests.isEmpty)
            }
        }
    }
    
    private func uploadDeviceTokenIfNeeded(_ token: String, forceUpload: Bool = false) {
        let lastToken = UserDefaults.standard.string(forKey: lastUploadedTokenKey)
        let lastServerURL = UserDefaults.standard.string(forKey: lastUploadedServerURLKey)
        
        if !forceUpload, lastToken == token, lastServerURL == pushServerBaseURL {
            DispatchQueue.main.async {
                self.remoteRegistrationMessage = "设备 Token 已同步到服务器"
            }
            return
        }
        
        guard let registerURL = URL(string: "\(pushServerBaseURL)/api/device/register") else {
            DispatchQueue.main.async {
                self.remoteRegistrationMessage = "服务器地址无效，请检查格式"
            }
            return
        }
        
        let payload = DeviceRegistrationPayload(
            deviceToken: token,
            bundleId: Bundle.main.bundleIdentifier ?? "unknown.bundle.id",
            environment: appEnvironment,
            platform: "ios",
            registeredAt: ISO8601DateFormatter().string(from: Date())
        )
        
        var request = URLRequest(url: registerURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            DispatchQueue.main.async {
                self.remoteRegistrationMessage = "Token 编码失败: \(error.localizedDescription)"
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    self.remoteRegistrationMessage = "上传 Token 失败: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.remoteRegistrationMessage = "上传 Token 失败: 无效服务器响应"
                    return
                }
                
                if (200..<300).contains(httpResponse.statusCode) {
                    UserDefaults.standard.set(token, forKey: self.lastUploadedTokenKey)
                    UserDefaults.standard.set(self.pushServerBaseURL, forKey: self.lastUploadedServerURLKey)
                    self.remoteRegistrationMessage = "设备 Token 已同步到服务器"
                } else {
                    let message = Self.extractMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                    self.remoteRegistrationMessage = "服务器拒绝注册: \(message)"
                }
            }
        }.resume()
    }
    
    private func normalizedServerURL(from value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""
        }
        
        let withScheme = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        return withScheme.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    
    private var appEnvironment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
    
    private static func extractMessage(from data: Data?) -> String? {
        guard let data else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = object["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct DeviceRegistrationPayload: Encodable {
    let deviceToken: String
    let bundleId: String
    let environment: String
    let platform: String
    let registeredAt: String
}
