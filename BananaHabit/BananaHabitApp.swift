import SwiftUI
import SwiftData

@main
struct BananaHabitApp: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Item.self,
                Mood.self
            ])
            let modelConfiguration = ModelConfiguration("BananaHabit", schema: schema)
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
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