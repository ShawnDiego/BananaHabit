import SwiftUI
import SwiftData

private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var selectedTab: Binding<Int> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView()
                .tabItem {
                    Label("概览", systemImage: "house")
                }
                .tag(0)
            
            ItemListView()
                .tabItem {
                    Label("事项", systemImage: "list.bullet")
                }
                .tag(1)
            
            PomodoroView()
                .tabItem {
                    Label("专注", systemImage: "timer")
                }
                .tag(2)
            
            DiaryListView()
                .tabItem {
                    Label("日记", systemImage: "book.closed")
                }
                .tag(3)
        }
        .environment(\.selectedTab, $selectedTab)
    }
} 