import LocalAuthentication
import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authError: String?
    private let securitySettings = SecuritySettings()
    
    init() {
        // 如果没有开启Face ID，则默认已认证
        if !securitySettings.isFaceIDEnabled {
            isAuthenticated = true
        }
    }
    
    func authenticate() {
        // 如果没有开启Face ID，直接返回已认证
        guard securitySettings.isFaceIDEnabled else {
            isAuthenticated = true
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "请使用Face ID解锁应用") { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.isAuthenticated = true
                        self.authError = nil
                    } else {
                        self.isAuthenticated = false
                        if let error = error {
                            switch error {
                            case LAError.userCancel:
                                self.authError = "验证已取消"
                            case LAError.userFallback:
                                self.authError = "请使用Face ID验证"
                            case LAError.biometryNotAvailable:
                                self.authError = "Face ID不可用"
                            case LAError.biometryNotEnrolled:
                                self.authError = "请先在系统设置中设置Face ID"
                            default:
                                self.authError = "验证失败，请重试"
                            }
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                if let error = error {
                    switch error.code {
                    case LAError.biometryNotAvailable.rawValue:
                        self.authError = "此设备不支持Face ID"
                    case LAError.biometryNotEnrolled.rawValue:
                        self.authError = "请先在系统设置中设置Face ID"
                    default:
                        self.authError = "Face ID不可用"
                    }
                }
                // 如果不支持Face ID，暂时允许访问
                self.isAuthenticated = true
            }
        }
    }
    
    // 添加重置认证状态的方法
    func resetAuthentication() {
        // 如果开启了Face ID，则重置认证状态
        if securitySettings.isFaceIDEnabled {
            isAuthenticated = false
            authError = nil
        }
    }
} 