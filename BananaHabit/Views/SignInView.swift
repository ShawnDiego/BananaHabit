import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userVM: UserViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Text("登录以同步数据")
                    .font(.title2)
                    .fontWeight(.bold)
                
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInWithApple(result)
                }
                .frame(height: 50)
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            switch auth.credential {
            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                let userId = appleIDCredential.user
                
                // 获取用户名
                var userName = "用户"
                if let fullName = appleIDCredential.fullName {
                    let formatter = PersonNameComponentsFormatter()
                    userName = formatter.string(from: fullName).trimmingCharacters(in: .whitespaces)
                    
                    // 如果格式化后的名字为空，使用备选方案
                    if userName.isEmpty {
                        userName = [
                            fullName.givenName,
                            fullName.familyName
                        ].compactMap { $0 }
                         .joined(separator: " ")
                         .trimmingCharacters(in: .whitespaces)
                    }
                    
                    // 如果还是空的，使用默认名
                    if userName.isEmpty {
                        userName = "用户"
                    }
                }
                
                // 创建用户
                var user = User(
                    id: userId,
                    name: userName
                )
                
                // 如果有邮箱，保存邮箱
                if let email = appleIDCredential.email {
                    user.email = email
                }
                
                // 更新用户状态
                userVM.currentUser = user
                userVM.isAuthenticated = true
                userVM.saveUserState()
                
                dismiss()
                
            default:
                break
            }
        case .failure(let error):
            print("登录失败: \(error.localizedDescription)")
        }
    }
} 