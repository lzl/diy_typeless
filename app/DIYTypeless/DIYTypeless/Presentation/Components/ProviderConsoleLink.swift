import SwiftUI
import AppKit

struct ProviderConsoleLink: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text("Don't have an API key? ")
                    .foregroundColor(.secondary)
                Text("Get one here")
                    .foregroundColor(.accentColor)
                    .underline()
            }
            .font(.system(size: 13))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
