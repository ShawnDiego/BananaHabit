import SwiftUI
import LocalAuthentication

class SecuritySettings: ObservableObject {
    @Published var isFaceIDEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isFaceIDEnabled, forKey: "isFaceIDEnabled")
        }
    }
    
    init() {
        self.isFaceIDEnabled = UserDefaults.standard.bool(forKey: "isFaceIDEnabled")
    }
    
    func isFaceIDAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}

struct SettingsView: View {
    @StateObject private var securitySettings = SecuritySettings()
    @State private var showingBiometricAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("安全")) {
                    if securitySettings.isFaceIDAvailable() {
                        Toggle(isOn: $securitySettings.isFaceIDEnabled) {
                            Label {
                                Text("Face ID 解锁")
                            } icon: {
                                Image(systemName: "faceid")
                                    .foregroundColor(.blue)
                            }
                        }
                        .onChange(of: securitySettings.isFaceIDEnabled) { newValue in
                            if newValue {
                                authenticateWithFaceID()
                            }
                        }
                        
                        if securitySettings.isFaceIDEnabled {
                            Text("启动应用时需要Face ID验证")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 其他设置选项可以在这里添加
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
        .alert("Face ID 设置", isPresented: $showingBiometricAlert) {
            Button("确定", role: .cancel) {
                securitySettings.isFaceIDEnabled = false
            }
        } message: {
            Text("无法启用Face ID，请确保您的设备支持Face ID并已在系统设置中启用。")
        }
    }
    
    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "确认启用Face ID") { success, error in
                DispatchQueue.main.async {
                    if !success {
                        securitySettings.isFaceIDEnabled = false
                    }
                }
            }
        } else {
            showingBiometricAlert = true
        }
    }
}

#Preview {
    SettingsView()
} 