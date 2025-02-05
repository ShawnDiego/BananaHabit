import SwiftUI
import SwiftData

@main
struct BananaHabitApp: App {
    let container: ModelContainer
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        do {
            // 配置 Schema 版本
            let schema = Schema([
                Item.self,
                Mood.self,
                Diary.self
            ])
            
            // 创建配置
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            // 尝试创建容器
            do {
                container = try ModelContainer(for: schema, configurations: modelConfiguration)
            } catch {
                print("创建容器失败，正在清理旧数据: \(error)")
                // 删除应用数据
                let url = URL.applicationSupportDirectory
                    .appending(path: "default.store")
                try? FileManager.default.removeItem(at: url)
                // 重新创建容器
                container = try ModelContainer(for: schema, configurations: modelConfiguration)
            }
            
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(userViewModel)
                        .modelContainer(container)
                } else {
                    LockScreenView()
                        .environmentObject(authManager)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background {
                    // 当应用进入后台时，重置认证状态
                    authManager.resetAuthentication()
                }
            }
        }
    }
}

struct LockScreenView: View {
    @StateObject private var securitySettings = SecuritySettings()
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            if securitySettings.isFaceIDAvailable() {
                Text("请使用Face ID解锁")
                    .font(.title2)
                
                if let error = authManager.authError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding(.top, 8)
                }
                
                Button(action: {
                    authManager.authenticate()
                }) {
                    Label("重新验证", systemImage: "faceid")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                }
                .padding(.top, 20)
            } else {
                Text("请在设置中开启Face ID")
                    .font(.title2)
            }
        }
        .onAppear {
            if securitySettings.isFaceIDAvailable() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authManager.authenticate()
                }
            }
        }
    }
} 
