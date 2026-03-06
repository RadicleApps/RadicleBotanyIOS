import Foundation
import SwiftUI
import UIKit

/// Intelligence Backend Service — Multi-tier botanical intelligence integration.
///
/// Users bring their own backends (Claude, ChatGPT) or use the owner's universal backend.
/// RadicleBotany provides context, receives insights. Privacy-first: no data collection.
///
/// 3-tier fallback chain:
/// 1. User's own API key (BYOC — Claude or ChatGPT) — unlimited, user-funded
/// 2. Owner's OpenAI backend (gpt-4o-mini) — available to all, rate-limited
/// 3. Local intelligence rules — pattern-based fallback

// MARK: - Intelligence Backend Protocol

protocol IntelligenceBackend {
    var name: String { get }
    var isConfigured: Bool { get }
    func sendContext(_ context: BotanyContext) async throws -> Insight
    func testConnection() async -> Bool
}

// MARK: - Botany Context

struct BotanyContext: Codable {
    var currentScreen: String
    var recentActions: [String]
    var timestamp: Date
    var query: String?
    var conversationHistory: [[String: String]]?

    func asPrompt() -> String {
        if let userQuery = query {
            return userQuery
        }

        var prompt = "User is on \(currentScreen) screen"

        if !recentActions.isEmpty {
            prompt += ". Recent actions: \(recentActions.joined(separator: ", "))"
        }

        prompt += "."
        return prompt
    }
}

// MARK: - Insight Response

struct Insight: Codable {
    var title: String
    var message: String
    var actionable: Bool
    var links: [String]?
    var timestamp: Date

    init(title: String, message: String, actionable: Bool = false, links: [String]? = nil) {
        self.title = title
        self.message = message
        self.actionable = actionable
        self.links = links
        self.timestamp = Date()
    }
}

// MARK: - Claude API Backend (BYOC)

final class ClaudeAPIBackend: IntelligenceBackend {
    let name = "Claude"

    var isConfigured: Bool {
        APIKeyManager.shared.getClaudeKey() != nil
    }

    func sendContext(_ context: BotanyContext) async throws -> Insight {
        guard let apiKey = APIKeyManager.shared.getClaudeKey() else {
            throw IntelligenceError.notConfigured
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are a botanical assistant for RadicleBotany, helping people learn about plants and identify species.

        Screen: \(context.currentScreen)

        Provide concise, educational guidance on:
        - Plant identification (morphological features, diagnostic traits)
        - Botanical terminology (anatomy, taxonomy, ecology)
        - Species information (habitat, range, conservation status)
        - Growing conditions and care

        Keep under 200 words. Be direct and educational.

        After your response, add a [SOURCES] block listing species, families, terms, or resources:
        [SOURCES]
        - Species: Genus species (Common Name)
        - Family: Familyname (Common name)
        - Term: Botanical term
        - Source: Reference name
        Only include sources you actually cited. Omit if none apply.
        """

        // Build messages array with conversation history for multi-turn context
        var messagesArray: [[String: Any]] = []
        if let history = context.conversationHistory {
            messagesArray.append(contentsOf: history.map { $0 as [String: Any] })
        }
        messagesArray.append(["role": "user", "content": context.asPrompt()])

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1024,
            "messages": messagesArray,
            "system": systemPrompt
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw IntelligenceError.apiError("Claude API error (code \(httpResponse.statusCode)): \(message)")
            }
            throw IntelligenceError.apiError("Claude API error (code \(httpResponse.statusCode))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw IntelligenceError.apiError("Unexpected response format from Claude API")
        }

        return Insight(title: "Claude's Analysis", message: text, links: [])
    }

    func testConnection() async -> Bool {
        guard isConfigured else { return false }
        do {
            let testContext = BotanyContext(currentScreen: "test", recentActions: [], timestamp: Date(), query: "test")
            _ = try await sendContext(testContext)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - ChatGPT API Backend (BYOC)

final class ChatGPTBackend: IntelligenceBackend {
    let name = "ChatGPT"

    var isConfigured: Bool {
        APIKeyManager.shared.getOpenAIKey() != nil
    }

    func sendContext(_ context: BotanyContext) async throws -> Insight {
        guard let apiKey = APIKeyManager.shared.getOpenAIKey() else {
            throw IntelligenceError.notConfigured
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = """
        You are a botanical assistant for RadicleBotany, helping people learn about plants and identify species.

        Screen: \(context.currentScreen)

        Provide concise, educational guidance on:
        - Plant identification (morphological features, diagnostic traits)
        - Botanical terminology (anatomy, taxonomy, ecology)
        - Species information (habitat, range, conservation status)
        - Growing conditions and care

        Keep under 200 words. Be direct and educational.

        After your response, add a [SOURCES] block listing species, families, terms, or resources:
        [SOURCES]
        - Species: Genus species (Common Name)
        - Family: Familyname (Common name)
        - Term: Botanical term
        - Source: Reference name
        Only include sources you actually cited. Omit if none apply.
        """

        // Build messages array with conversation history for multi-turn context
        var messagesArray: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        if let history = context.conversationHistory {
            messagesArray.append(contentsOf: history.map { $0 as [String: Any] })
        }
        messagesArray.append(["role": "user", "content": context.asPrompt()])

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messagesArray,
            "max_tokens": 1024,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw IntelligenceError.apiError("ChatGPT API error (code \(httpResponse.statusCode)): \(message)")
            }
            throw IntelligenceError.apiError("ChatGPT API error (code \(httpResponse.statusCode))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw IntelligenceError.apiError("Unexpected response format from ChatGPT API")
        }

        return Insight(title: "ChatGPT's Analysis", message: text, links: [])
    }

    func testConnection() async -> Bool {
        guard isConfigured else { return false }
        do {
            let testContext = BotanyContext(currentScreen: "test", recentActions: [], timestamp: Date(), query: "test")
            _ = try await sendContext(testContext)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Owner OpenAI Backend (Universal — all users)

final class OwnerOpenAIBackend: IntelligenceBackend {
    let name = "RadicleBotany Enhanced"

    var isConfigured: Bool {
        OwnerBackendConfig.isAvailable
    }

    func sendContext(_ context: BotanyContext) async throws -> Insight {
        guard let apiKey = OwnerBackendConfig.getAPIKey() else {
            throw IntelligenceError.notConfigured
        }

        // Check rate limit
        let tier = await MainActor.run { StoreManager.shared.userTier }
        guard RateLimitManager.shared.canQuery(tier: tier) else {
            let limit = RateLimitManager.shared.dailyLimit(for: tier)
            throw IntelligenceError.apiError("Daily query limit reached (\(limit) queries). Resets at midnight.")
        }

        // Check cache first
        let query = context.asPrompt()
        if let cached = ResponseCache.shared.get(query: query, screen: context.currentScreen) {
            return Insight(title: "RadicleBotany", message: cached, links: [])
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw IntelligenceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = OwnerBackendConfig.requestTimeout

        let systemPrompt = OwnerBackendConfig.systemPrompt + """

        Current screen: \(context.currentScreen)
        """

        // Build messages array with conversation history for multi-turn context
        var messagesArray: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        if let history = context.conversationHistory {
            messagesArray.append(contentsOf: history.map { $0 as [String: Any] })
        }
        messagesArray.append(["role": "user", "content": query])

        let body: [String: Any] = [
            "model": OwnerBackendConfig.model,
            "max_tokens": OwnerBackendConfig.maxTokens,
            "messages": messagesArray
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw IntelligenceError.apiError("Service error: \(message)")
            }
            throw IntelligenceError.apiError("Service temporarily unavailable")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageObj = firstChoice["message"] as? [String: Any],
              let text = messageObj["content"] as? String else {
            throw IntelligenceError.apiError("Unexpected response format")
        }

        // Record query against rate limit
        RateLimitManager.shared.recordQuery(tier: tier)

        // Cache the response
        let ttl = ResponseCache.ttlFor(query: query)
        ResponseCache.shared.set(query: query, screen: context.currentScreen, response: text, ttl: ttl)

        return Insight(title: "RadicleBotany", message: text, links: [])
    }

    func testConnection() async -> Bool {
        return isConfigured
    }
}

// MARK: - Local Intelligence (Fallback)

class LocalIntelligenceBackend: IntelligenceBackend {
    let name = "Local Intelligence"
    var isConfigured: Bool { true }

    func sendContext(_ context: BotanyContext) async throws -> Insight {
        let screen = context.currentScreen

        if screen.contains("Learn") || screen.contains("Species") {
            return Insight(
                title: "Botanical Learning",
                message: "Browse species by family, morphological traits, or bloom season. Tap any species for detailed identification features including leaf shape, flower structure, and habitat information.",
                actionable: true
            )
        }

        if screen.contains("Botanize") || screen.contains("Observe") || screen.contains("Capture") {
            return Insight(
                title: "Plant Identification",
                message: "For best identification results, photograph the plant's leaves, flowers, and overall growth habit. Note the leaf arrangement (alternate vs opposite) and any distinguishing features like bark texture or fruit type.",
                actionable: true
            )
        }

        if screen.contains("Journal") {
            return Insight(
                title: "Field Observations",
                message: "Document location, habitat type, and associated species in your observations. Phenological notes (bloom stage, fruiting, dormancy) add scientific value to your records.",
                actionable: true
            )
        }

        return Insight(
            title: "RadicleBotany Intelligence",
            message: "Local intelligence is active. Configure Claude or ChatGPT in Dashboard > Intelligence for enhanced botanical responses.",
            actionable: true
        )
    }

    func testConnection() async -> Bool {
        return true
    }
}

// MARK: - Intelligence Backend Service (Singleton)

@MainActor
final class IntelligenceBackendService: ObservableObject {
    static let shared = IntelligenceBackendService()

    @Published var currentInsight: Insight?
    @Published var isProcessing: Bool = false

    @AppStorage("radiclebotany_preferred_ai_backend") private var preferredBackend: String = "claude"

    private let claudeAPIBackend = ClaudeAPIBackend()
    private let chatGPTBackend = ChatGPTBackend()
    private let ownerBackend = OwnerOpenAIBackend()
    private let localBackend = LocalIntelligenceBackend()

    private init() {}

    // MARK: - Public API

    func requestInsight(context: BotanyContext, userTier: UserTier = .free) async -> Insight? {
        isProcessing = true

        do {
            let backend = selectBackend(for: userTier)
            let insight = try await backend.sendContext(context)
            currentInsight = insight
            isProcessing = false
            return insight
        } catch {
            // Fallback to local on error
            do {
                let localInsight = try await localBackend.sendContext(context)
                currentInsight = localInsight
                isProcessing = false
                return localInsight
            } catch {
                isProcessing = false
                return nil
            }
        }
    }

    /// 4-tier backend selection
    private func selectBackend(for tier: UserTier) -> IntelligenceBackend {
        // Tier 1: User's own API key (BYOC)
        if claudeAPIBackend.isConfigured && chatGPTBackend.isConfigured {
            return preferredBackend == "claude" ? claudeAPIBackend : chatGPTBackend
        }
        if claudeAPIBackend.isConfigured { return claudeAPIBackend }
        if chatGPTBackend.isConfigured { return chatGPTBackend }

        // Tier 2: Owner backend — available to all, rate-limited by tier
        if ownerBackend.isConfigured && RateLimitManager.shared.canQuery(tier: tier) {
            return ownerBackend
        }

        // Tier 3: Local intelligence rules
        return localBackend
    }

    func testConnections() async -> [String: Bool] {
        var results: [String: Bool] = [:]

        if claudeAPIBackend.isConfigured {
            results["Claude"] = await claudeAPIBackend.testConnection()
        }
        if chatGPTBackend.isConfigured {
            results["ChatGPT"] = await chatGPTBackend.testConnection()
        }
        results["Local"] = await localBackend.testConnection()

        return results
    }

    func getBackendName(for tier: UserTier) -> String {
        if claudeAPIBackend.isConfigured && chatGPTBackend.isConfigured {
            return preferredBackend == "chatgpt" ? "ChatGPT" : "Claude"
        }
        if claudeAPIBackend.isConfigured { return "Claude" }
        if chatGPTBackend.isConfigured { return "ChatGPT" }
        if ownerBackend.isConfigured { return "Enhanced" }
        return "Local"
    }

    var hasAIConfigured: Bool {
        claudeAPIBackend.isConfigured || chatGPTBackend.isConfigured || ownerBackend.isConfigured
    }

    var isOwnerBackendActive: Bool {
        !claudeAPIBackend.isConfigured && !chatGPTBackend.isConfigured && ownerBackend.isConfigured
    }
}

// MARK: - Intelligence Errors

enum IntelligenceError: LocalizedError {
    case notConfigured
    case invalidURL
    case serverError
    case networkError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Intelligence backend not configured"
        case .invalidURL:
            return "Invalid server URL"
        case .serverError:
            return "Server returned an error"
        case .networkError:
            return "Network connection failed"
        case .apiError(let message):
            return message
        }
    }
}
