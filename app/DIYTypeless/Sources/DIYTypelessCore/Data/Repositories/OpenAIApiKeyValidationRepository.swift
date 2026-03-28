import Foundation

public final class OpenAIApiKeyValidationRepository: ApiKeyValidationRepository {
    public init() {}

    public func validate(key: String) async throws {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw ValidationError(message: "OpenAI validation failed: invalid URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ValidationError(message: "OpenAI validation failed: no response.")
        }

        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw ValidationError(message: "OpenAI API key is invalid or expired.")
        default:
            throw ValidationError(message: "OpenAI API error: HTTP \(http.statusCode).")
        }
    }
}
