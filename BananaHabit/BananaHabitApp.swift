import SwiftUI
import SwiftData

@main
struct BananaHabitApp: App {
    let container: ModelContainer
    
    init() {
        do {
            // 配置 Schema 版本
            let schema = Schema([
                Item.self,
                Mood.self
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
            ContentView()
        }
        .modelContainer(container)
    }
} 
