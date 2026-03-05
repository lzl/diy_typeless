import Foundation

public protocol KeyMonitoringRepository: AnyObject {
    var onFnDown: (() -> Void)? { get set }
    var onFnUp: (() -> Void)? { get set }
    func start() -> Bool
    func stop()
}
