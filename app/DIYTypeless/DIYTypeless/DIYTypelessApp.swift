import SwiftUI

@main
struct DIYTypelessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        state.start()
    }

    var body: some Scene {
        MenuBarExtra("DIY Typeless", systemImage: "waveform") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep onboarding/completion visible on first launch; only force accessory mode when no window is shown.
        if NSApp.windows.allSatisfy({ !$0.isVisible }) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When user clicks dock icon, show settings
        NotificationCenter.default.post(name: .showSettings, object: nil)
        return true
    }
}

extension Notification.Name {
    static let showSettings = Notification.Name("showSettings")
}
