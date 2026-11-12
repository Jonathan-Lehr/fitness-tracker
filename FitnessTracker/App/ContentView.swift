import SwiftUI

struct ContentView: View {
    #if os(macOS)
    /// Measured window-edge-to-card horizontal space; see WindowSizing.
    @AppStorage(WindowSizing.chromeKey) private var cardChrome: Double = 0
    @State private var rootWidth: CGFloat = 0
    private let cardMetrics = SummaryCardMetrics.shared
    #endif

    var body: some View {
        TabView {
            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
            ProgramListView()
                .tabItem { Label("Programs", systemImage: "figure.indoor.cycle") }
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
        }
        #if os(macOS)
        // Minimum width keeps the summary card's 3-column layout intact; with
        // .windowResizability(.contentMinSize) this is also the window's minimum.
        .frame(minWidth: WindowSizing.minWidth(chrome: cardChrome), minHeight: WindowSizing.minHeight)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rootWidth = $0 }
        // Re-measure only when the card lays out (it's on screen), so a resize on another tab
        // doesn't pair a new window width with a stale card width.
        .onChange(of: cardMetrics.cardWidth) { _, card in
            let chrome = (rootWidth - card).rounded(.up)
            if card > 0, rootWidth > 0, chrome >= 0, chrome < 200, Double(chrome) != cardChrome {
                cardChrome = Double(chrome)
            }
        }
        #endif
    }
}
