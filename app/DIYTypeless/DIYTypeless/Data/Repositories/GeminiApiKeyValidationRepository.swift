import Foundation

/// Repository implementation for validating Gemini API keys.
final class GeminiApiKeyValidationRepository: ApiKeyValidationRepository {
    func validate(key: String) async throws {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)") else {
            throw ValidationError(message: "Gemini validation failed: invalid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ValidationError(message: "Gemini validation failed: no response.")
        }

        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw ValidationError(message: "Gemini API key is invalid or expired.")
        default:
            throw ValidationError(message: "Gemini API error: HTTP \(http.statusCode).")
        }
    }
}
