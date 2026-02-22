import Foundation

protocol KeyMonitoringRepository: AnyObject, Sendable {
    var onFnDown: (() -> Void)? { get set }
    var onFnUp: (() -> Void)? { get set }
    func start() -> Bool
    func stop()
}
