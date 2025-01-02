import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userVM: UserViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "person.circle")
                    .font(.system(size: 70))
                    .foregroundColor(.secondary)
                
                Text("开始使用")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("登录后即可记录和同步您的心情数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                SignInWithAppleButton { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        // 处理登录成功
                        handleSignInWithApple(authResults)
                    case .failure(let error):
                        print("Authorization failed: \(error.localizedDescription)")
                    }
                }
                .frame(height: 44)
                .padding(.horizontal)
                
                Button("暂不登录") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .padding(.top)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func handleSignInWithApple(_ result: ASAuthorization) {
        if let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
           let fullName = appleIDCredential.fullName {
            // 创建新用户
            let user = User(
                id: appleIDCredential.user,
                name: "\(fullName.givenName ?? "") \(fullName.familyName ?? "")",
                email: appleIDCredential.email
            )
            
            // 更新用户状态
            userVM.currentUser = user
            userVM.isAuthenticated = true
            
            // 关闭登录页面
            dismiss()
        }
    }
} 