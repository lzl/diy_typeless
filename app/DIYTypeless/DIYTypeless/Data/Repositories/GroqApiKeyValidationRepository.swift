import Foundation

/// Repository implementation for validating Groq API keys.
final class GroqApiKeyValidationRepository: ApiKeyValidationRepository {
    func validate(key: String) async throws {
        guard let url = URL(string: "https://api.groq.com/openai/v1/models") else {
            throw ValidationError(message: "Groq validation failed: invalid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ValidationError(message: "Groq validation failed: no response.")
        }

        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw ValidationError(message: "Groq API key is invalid or expired.")
        default:
            throw ValidationError(message: "Groq API error: HTTP \(http.statusCode).")
        }
    }
}
