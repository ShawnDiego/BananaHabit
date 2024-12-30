import SwiftUI
import SwiftData

@main
struct BananaHabitApp: App {
    let container: ModelContainer
    
    init() {
        do {
            let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: Item.self, Mood.self, configurations: modelConfiguration)
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
