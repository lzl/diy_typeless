import AppKit
import SwiftUI
import Combine

final class StatusOverlayViewModel: ObservableObject {
    @Published var status: RecordingStatus = .idle
    @Published var message: String = ""
}

final class StatusOverlayController {
    private let window: NSWindow
    private let viewModel = StatusOverlayViewModel()

    init() {
        let hostingView = NSHostingController(rootView: StatusOverlayView(model: viewModel))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.contentView = hostingView.view
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.window = window
        positionWindow()
    }

    func show(status: RecordingStatus, message: String) {
        DispatchQueue.main.async {
            self.viewModel.status = status
            self.viewModel.message = message
            self.positionWindow()
            self.window.alphaValue = 1.0
            self.window.orderFrontRegardless()
        }
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let width: CGFloat = 360
        let height: CGFloat = 72
        let x = frame.midX - width / 2
        let y = frame.minY + 28
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

struct StatusOverlayView: View {
    @ObservedObject var model: StatusOverlayViewModel

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.status.rawValue)
                    .font(.headline)
                Text(model.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch model.status {
        case .idle:
            return .gray
        case .recording:
            return .red
        case .transcribing:
            return .blue
        case .polishing:
            return .purple
        case .done:
            return .green
        case .error:
            return .orange
        }
    }
}

