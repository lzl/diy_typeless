import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button("Settings...") {
            appState.showOnboarding()
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
