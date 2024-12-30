import SwiftUI
import SwiftData

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
        }
    }
} 