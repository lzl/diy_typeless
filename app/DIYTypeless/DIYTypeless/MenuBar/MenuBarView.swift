import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

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
