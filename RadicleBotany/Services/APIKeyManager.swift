import Foundation

/// Manages API keys for external intelligence backends (Claude, ChatGPT).
/// Provides key validation, secure Keychain storage, and status tracking.
@MainActor
class APIKeyManager: ObservableObject {
    static let shared = APIKeyManager()

    @Published var claudeKeyConfigured: Bool = false
    @Published var openAIKeyConfigured: Bool = false

    private let keychain = KeychainManager.shared

    private init() {
        refreshKeyStatus()
    }

    // MARK: - Public API

    /// Save Claude API key after validation
    func saveClaudeKey(_ key: String) async throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            throw APIKeyError.emptyKey
        }

        guard trimmedKey.hasPrefix("sk-ant-") else {
            throw APIKeyError.invalidFormat(service: "Claude")
        }

        try await testClaudeKey(trimmedKey)

        guard keychain.save(trimmedKey, for: .claudeAPIKey) else {
            throw APIKeyError.saveFailed
        }

        claudeKeyConfigured = true
    }

    /// Save OpenAI API key after validation
    func saveOpenAIKey(_ key: String) async throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            throw APIKeyError.emptyKey
        }

        guard trimmedKey.hasPrefix("sk-") else {
            throw APIKeyError.invalidFormat(service: "ChatGPT")
        }

        try await testOpenAIKey(trimmedKey)

        guard keychain.save(trimmedKey, for: .openAIAPIKey) else {
            throw APIKeyError.saveFailed
        }

        openAIKeyConfigured = true
    }

    /// Retrieve Claude API key
    nonisolated func getClaudeKey() -> String? {
        return keychain.retrieve(for: .claudeAPIKey)
    }

    /// Retrieve OpenAI API key
    nonisolated func getOpenAIKey() -> String? {
        return keychain.retrieve(for: .openAIAPIKey)
    }

    /// Delete Claude API key
    func deleteClaudeKey() {
        _ = keychain.delete(for: .claudeAPIKey)
        claudeKeyConfigured = false
    }

    /// Delete OpenAI API key
    func deleteOpenAIKey() {
        _ = keychain.delete(for: .openAIAPIKey)
        openAIKeyConfigured = false
    }

    /// Refresh key configuration status
    func refreshKeyStatus() {
        claudeKeyConfigured = keychain.exists(for: .claudeAPIKey)
        openAIKeyConfigured = keychain.exists(for: .openAIAPIKey)
    }

    // MARK: - Key Validation

    private func testClaudeKey(_ key: String) async throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIKeyError.networkError
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIKeyError.invalidKey(service: "Claude")
        case 429:
            throw APIKeyError.rateLimited
        default:
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw APIKeyError.apiError(message)
            }
            throw APIKeyError.unknownError(code: httpResponse.statusCode)
        }
    }

    private func testOpenAIKey(_ key: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "user", "content": "test"]
            ],
            "max_tokens": 10
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIKeyError.networkError
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIKeyError.invalidKey(service: "ChatGPT")
        case 429:
            throw APIKeyError.rateLimited
        default:
            throw APIKeyError.unknownError(code: httpResponse.statusCode)
        }
    }
}

// MARK: - Errors

enum APIKeyError: LocalizedError {
    case emptyKey
    case invalidFormat(service: String)
    case invalidKey(service: String)
    case saveFailed
    case networkError
    case rateLimited
    case apiError(String)
    case unknownError(code: Int)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "API key cannot be empty"
        case .invalidFormat(let service):
            return "\(service) API keys must start with the correct prefix"
        case .invalidKey(let service):
            return "\(service) API key is invalid or expired"
        case .saveFailed:
            return "Failed to save API key securely"
        case .networkError:
            return "Network error while testing API key"
        case .rateLimited:
            return "Rate limited. Please wait and try again."
        case .apiError(let message):
            return message
        case .unknownError(let code):
            return "API error (code \(code))"
        }
    }
}
