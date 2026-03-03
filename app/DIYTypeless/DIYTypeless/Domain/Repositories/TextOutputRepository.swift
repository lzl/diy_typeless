import Foundation

protocol TextOutputRepository: Sendable {
    func deliver(text: String) -> OutputResult
    func copyToClipboard(text: String)
}
