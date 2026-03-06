import SwiftUI
import AppKit
import DIYTypelessCore

struct ProviderConsoleLink: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text("Don't have an API key?")
                .foregroundStyle(Color.textSecondary)

            Button("Get one here", action: action)
                .quietLinkButton()
        }
        .font(.system(size: 13))
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
