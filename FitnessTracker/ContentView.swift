import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
            ProgramListView()
                .tabItem { Label("Programs", systemImage: "figure.indoor.cycle") }
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
        }
    }
}
