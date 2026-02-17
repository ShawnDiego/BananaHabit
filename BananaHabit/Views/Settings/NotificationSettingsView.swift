import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTime = Date()
    @State private var hasNotification = false
    @State private var pushServerURL = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("每日提醒", isOn: $hasNotification)
                        .onChange(of: hasNotification) { oldValue, newValue in
                            if newValue {
                                requestNotificationPermission()
                            } else {
                                notificationManager.cancelAllNotifications()
                            }
                        }
                    
                    if hasNotification {
                        DatePicker("提醒时间",
                                 selection: $selectedTime,
                                 displayedComponents: .hourAndMinute)
                            .onChange(of: selectedTime) { oldValue, newValue in
                                notificationManager.scheduleDaily(at: newValue)
                            }
                    }
                } header: {
                    Text("通知设置")
                } footer: {
                    Text("开启后，我们会在设定的时间提醒你记录心情")
                }
                
                Section {
                    TextField("服务器地址", text: $pushServerURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                    
                    Button("保存服务器地址") {
                        savePushServerURL()
                    }
                    
                    Button("重新注册远程推送") {
                        registerRemotePush()
                    }
                    
                    Text(notificationManager.remoteRegistrationMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let token = notificationManager.apnsDeviceToken, !token.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("APNs Device Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(token)
                                .font(.caption2)
                                .textSelection(.enabled)
                        }
                    }
                } header: {
                    Text("远程推送")
                } footer: {
                    Text("填写运行在 macOS 的通知服务器地址，例如：http://192.168.1.20:8787")
                }
            }
            .navigationTitle("提醒设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                notificationManager.isNotificationScheduled { scheduled in
                    hasNotification = scheduled
                }
                pushServerURL = notificationManager.pushServerBaseURL
                notificationManager.refreshAuthorizationStatus()
            }
        }
    }
    
    private func savePushServerURL() {
        notificationManager.updatePushServerBaseURL(pushServerURL)
    }
    
    private func registerRemotePush() {
        savePushServerURL()
        if notificationManager.isNotificationsEnabled {
            notificationManager.registerForRemoteNotifications()
        } else {
            requestNotificationPermission()
        }
    }
    
    private func requestNotificationPermission() {
        notificationManager.requestPermission { granted in
            if granted {
                notificationManager.scheduleDaily(at: selectedTime)
            } else {
                hasNotification = false
            }
        }
    }
} 
