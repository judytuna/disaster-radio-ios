import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            NodeListView()
                .tabItem { Label("Nodes", systemImage: "antenna.radiowaves.left.and.right") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}
