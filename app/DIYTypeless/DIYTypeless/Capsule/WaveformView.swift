import Combine
import SwiftUI

struct WaveformView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.35, count: 12)
    private let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 3, height: 18 * levels[index])
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                levels = levels.map { _ in CGFloat.random(in: 0.25...1.0) }
            }
        }
    }
}
