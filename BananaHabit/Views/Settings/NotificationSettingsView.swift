import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTime = Date()
    @State private var isTimePickerShown = false
    @State private var hasNotification = false
    
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
            }
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