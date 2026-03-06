import SwiftUI
import AppKit
import DIYTypelessCore

struct ProviderConsoleLink: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("Don't have an API key?")
                    .foregroundStyle(Color.textSecondary)

                Text("Get one here")
                    .foregroundStyle(isHovered ? Color.brandAccent : Color.linkQuiet)
                    .underline(isHovered)
            }
            .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            self.isHovered = isHovered
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
