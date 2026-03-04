import SwiftUI
import DIYTypelessCore

struct CapsuleLayerRootView: View {
    let state: RecordingState

    var body: some View {
        Group {
            if let layer = state.voiceCommandResultLayer {
                VoiceCommandResultLayerView(state: state, layer: layer)
            } else {
                CapsuleView(state: state)
            }
        }
    }
}
