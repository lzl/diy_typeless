import DIYTypelessCore

// Temporary app-layer bridge for UniFFI error type conversion.
// Remove after GeminiLLMRepository migrates into DIYTypelessCore.
enum FFICoreErrorBridge {
    static func toCoreModuleError(_ ffiError: CoreError) -> DIYTypelessCore.CoreError {
        switch ffiError {
        case .Cancelled:
            return .Cancelled
        case .AudioDeviceUnavailable:
            return .AudioDeviceUnavailable
        case .RecordingAlreadyActive:
            return .RecordingAlreadyActive
        case .RecordingNotActive:
            return .RecordingNotActive
        case .AudioCapture(let message):
            return .AudioCapture(message)
        case .AudioProcessing(let message):
            return .AudioProcessing(message)
        case .Http(let message):
            return .Http(message)
        case .Api(let message):
            return .Api(message)
        case .Serialization(let message):
            return .Serialization(message)
        case .EmptyResponse:
            return .EmptyResponse
        case .Transcription(let message):
            return .Transcription(message)
        case .Config(let message):
            return .Config(message)
        }
    }
}
