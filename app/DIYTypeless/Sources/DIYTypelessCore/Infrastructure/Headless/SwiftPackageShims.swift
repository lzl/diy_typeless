#if SWIFT_PACKAGE
import Foundation

public protocol CancellationTokenProtocol: AnyObject, Sendable {
    func cancel()
    func isCancelled() -> Bool
}

open class CancellationToken: CancellationTokenProtocol, @unchecked Sendable {
    public struct NoHandle {
        public init() {}
    }

    private let lock = NSLock()
    private var cancelled = false

    required public init(unsafeFromHandle handle: UInt64) {
        _ = handle
    }

    public init(noHandle: NoHandle) {
        _ = noHandle
    }

    public convenience init() {
        self.init(noHandle: NoHandle())
    }

    open func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    open func isCancelled() -> Bool {
        lock.lock()
        let value = cancelled
        lock.unlock()
        return value
    }
}

public enum CoreError: Error, Equatable, Hashable, LocalizedError, Sendable {
    case Cancelled
    case AudioDeviceUnavailable
    case RecordingAlreadyActive
    case RecordingNotActive
    case AudioCapture(String)
    case AudioProcessing(String)
    case Http(String)
    case Api(String)
    case Serialization(String)
    case EmptyResponse
    case Transcription(String)
    case Config(String)

    public var errorDescription: String? {
        String(describing: self)
    }
}
#endif
