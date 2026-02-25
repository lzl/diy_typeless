import Foundation

protocol RecordingControlUseCaseProtocol: Sendable {
    func startRecording() async throws
    func warmupConnections() async
}
