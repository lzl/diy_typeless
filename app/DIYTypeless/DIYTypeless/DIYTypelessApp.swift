import SwiftUI

@main
struct DIYTypelessApp: App {
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        state.start()
    }

    var body: some Scene {
        MenuBarExtra("DIY Typeless", systemImage: "mic.fill") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}
