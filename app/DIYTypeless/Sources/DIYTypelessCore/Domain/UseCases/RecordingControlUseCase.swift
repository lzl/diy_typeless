import Foundation

public protocol RecordingControlUseCaseProtocol: Sendable {
    func startRecording() async throws
    func warmupConnections(llmProvider: ApiProvider) async
}
