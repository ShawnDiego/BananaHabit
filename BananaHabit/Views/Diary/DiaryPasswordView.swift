import SwiftUI

struct DiaryPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var diary: Diary
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    let isSettingPassword: Bool
    let onSuccess: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isSettingPassword {
                    Text("请设置6位数字密码")
                        .font(.headline)
                        .padding(.top)
                    
                    SecureField("输入密码", text: $password)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onChange(of: password) { _, newValue in
                            if newValue.count > 6 {
                                password = String(newValue.prefix(6))
                            }
                            // 只允许数字
                            password = newValue.filter { $0.isNumber }
                        }
                    
                    SecureField("确认密码", text: $confirmPassword)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onChange(of: confirmPassword) { _, newValue in
                            if newValue.count > 6 {
                                confirmPassword = String(newValue.prefix(6))
                            }
                            // 只允许数字
                            confirmPassword = newValue.filter { $0.isNumber }
                        }
                } else {
                    Text("请输入密码")
                        .font(.headline)
                        .padding(.top)
                    
                    SecureField("输入密码", text: $password)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .onChange(of: password) { _, newValue in
                            if newValue.count > 6 {
                                password = String(newValue.prefix(6))
                            }
                            // 只允许数字
                            password = newValue.filter { $0.isNumber }
                        }
                }
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .navigationTitle(isSettingPassword ? "设置密码" : "输入密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        if isSettingPassword {
                            if password.count != 6 {
                                showError = true
                                errorMessage = "密码必须是6位数字"
                                return
                            }
                            
                            if password != confirmPassword {
                                showError = true
                                errorMessage = "两次输入的密码不一致"
                                return
                            }
                            
                            diary.isLocked = true
                            diary.password = password
                            onSuccess()
                            dismiss()
                        } else {
                            if password == diary.password {
                                onSuccess()
                                dismiss()
                            } else {
                                showError = true
                                errorMessage = "密码错误"
                                password = ""
                            }
                        }
                    }
                    .disabled(isSettingPassword ? (password.isEmpty || confirmPassword.isEmpty) : password.isEmpty)
                }
            }
        }
    }
} 