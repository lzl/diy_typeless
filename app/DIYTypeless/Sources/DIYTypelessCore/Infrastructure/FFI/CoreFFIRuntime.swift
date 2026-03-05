import Foundation

public enum CoreFFIRuntimeError: Error, Equatable, Sendable {
    case unconfigured(String)
}

public struct CoreFFIRuntimeHandlers: Sendable {
    public typealias StartRecording = @Sendable () throws -> Void
    public typealias StopRecording = @Sendable () throws -> DomainAudioData
    public typealias WarmupGroqConnection = @Sendable () throws -> Void
    public typealias WarmupGeminiConnection = @Sendable () throws -> Void
    public typealias TranscribeAudioBytesCancellable = @Sendable (
        _ apiKey: String,
        _ audioBytes: Data,
        _ language: String?,
        _ cancellationToken: CancellationToken
    ) throws -> String
    public typealias PolishTextCancellable = @Sendable (
        _ apiKey: String,
        _ rawText: String,
        _ context: String?,
        _ cancellationToken: CancellationToken
    ) throws -> String
    public typealias ProcessTextWithLlmCancellable = @Sendable (
        _ apiKey: String,
        _ prompt: String,
        _ systemInstruction: String?,
        _ temperature: Float,
        _ cancellationToken: CancellationToken
    ) throws -> String

    public let startRecording: StartRecording
    public let stopRecording: StopRecording
    public let warmupGroqConnection: WarmupGroqConnection
    public let warmupGeminiConnection: WarmupGeminiConnection
    public let transcribeAudioBytesCancellable: TranscribeAudioBytesCancellable
    public let polishTextCancellable: PolishTextCancellable
    public let processTextWithLlmCancellable: ProcessTextWithLlmCancellable

    public init(
        startRecording: @escaping StartRecording,
        stopRecording: @escaping StopRecording,
        warmupGroqConnection: @escaping WarmupGroqConnection,
        warmupGeminiConnection: @escaping WarmupGeminiConnection,
        transcribeAudioBytesCancellable: @escaping TranscribeAudioBytesCancellable,
        polishTextCancellable: @escaping PolishTextCancellable,
        processTextWithLlmCancellable: @escaping ProcessTextWithLlmCancellable
    ) {
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.warmupGroqConnection = warmupGroqConnection
        self.warmupGeminiConnection = warmupGeminiConnection
        self.transcribeAudioBytesCancellable = transcribeAudioBytesCancellable
        self.polishTextCancellable = polishTextCancellable
        self.processTextWithLlmCancellable = processTextWithLlmCancellable
    }

    static var unconfigured: CoreFFIRuntimeHandlers {
        CoreFFIRuntimeHandlers(
            startRecording: { throw CoreFFIRuntimeError.unconfigured("startRecording") },
            stopRecording: { throw CoreFFIRuntimeError.unconfigured("stopRecording") },
            warmupGroqConnection: { throw CoreFFIRuntimeError.unconfigured("warmupGroqConnection") },
            warmupGeminiConnection: { throw CoreFFIRuntimeError.unconfigured("warmupGeminiConnection") },
            transcribeAudioBytesCancellable: { _, _, _, _ in
                throw CoreFFIRuntimeError.unconfigured("transcribeAudioBytesCancellable")
            },
            polishTextCancellable: { _, _, _, _ in
                throw CoreFFIRuntimeError.unconfigured("polishTextCancellable")
            },
            processTextWithLlmCancellable: { _, _, _, _, _ in
                throw CoreFFIRuntimeError.unconfigured("processTextWithLlmCancellable")
            }
        )
    }
}

public enum CoreFFIRuntime {
    private static let lock = NSLock()
    private static var handlers = CoreFFIRuntimeHandlers.unconfigured

    public static func configure(_ handlers: CoreFFIRuntimeHandlers) {
        lock.lock()
        defer { lock.unlock() }
        self.handlers = handlers
    }

    static func resetForTests() {
        lock.lock()
        defer { lock.unlock() }
        handlers = .unconfigured
    }

    public static func startRecording() throws {
        let handler = withHandlers { $0.startRecording }
        try handler()
    }

    public static func stopRecording() throws -> DomainAudioData {
        let handler = withHandlers { $0.stopRecording }
        return try handler()
    }

    public static func warmupGroqConnection() throws {
        let handler = withHandlers { $0.warmupGroqConnection }
        try handler()
    }

    public static func warmupGeminiConnection() throws {
        let handler = withHandlers { $0.warmupGeminiConnection }
        try handler()
    }

    public static func transcribeAudioBytesCancellable(
        apiKey: String,
        audioBytes: Data,
        language: String?,
        cancellationToken: CancellationToken
    ) throws -> String {
        let handler = withHandlers { $0.transcribeAudioBytesCancellable }
        return try handler(apiKey, audioBytes, language, cancellationToken)
    }

    public static func polishTextCancellable(
        apiKey: String,
        rawText: String,
        context: String?,
        cancellationToken: CancellationToken
    ) throws -> String {
        let handler = withHandlers { $0.polishTextCancellable }
        return try handler(apiKey, rawText, context, cancellationToken)
    }

    public static func processTextWithLlmCancellable(
        apiKey: String,
        prompt: String,
        systemInstruction: String?,
        temperature: Float,
        cancellationToken: CancellationToken
    ) throws -> String {
        let handler = withHandlers { $0.processTextWithLlmCancellable }
        return try handler(apiKey, prompt, systemInstruction, temperature, cancellationToken)
    }

    private static func withHandlers<T>(
        _ read: (CoreFFIRuntimeHandlers) -> T
    ) -> T {
        lock.lock()
        defer { lock.unlock() }
        return read(handlers)
    }
}
