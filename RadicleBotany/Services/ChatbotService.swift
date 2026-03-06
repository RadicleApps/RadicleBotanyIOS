import Foundation
import SwiftUI

/// RadicleBotany Chatbot Service — Botanical conversational assistant.
///
/// Adaptive intelligence architecture:
/// - AI-powered: Uses configured intelligence backend (Claude/ChatGPT)
/// - Rule-based fallback: Local FAQ + pattern matching when no backend available
/// - Context-aware: Knows current screen, recent actions

// MARK: - Content Reference Model

enum ReferenceType: String, Codable {
    case species = "species"
    case family = "family"
    case term = "term"
    case article = "article"
    case faq = "faq"
}

struct ContentReference: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let url: String?
    let type: ReferenceType
    let detail: String?

    init(title: String, url: String? = nil, type: ReferenceType, detail: String? = nil) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.type = type
        self.detail = detail
    }

    var icon: String {
        switch type {
        case .species: return "leaf.fill"
        case .family: return "tree.fill"
        case .term: return "text.book.closed"
        case .article: return "newspaper"
        case .faq: return "book.closed"
        }
    }
}

// MARK: - Chatbot Message Models

enum MessageSender {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let sender: MessageSender
    let content: String
    let references: [ContentReference]
    let timestamp: Date
    let isTyping: Bool

    init(sender: MessageSender, content: String, references: [ContentReference] = [], isTyping: Bool = false) {
        self.id = UUID()
        self.sender = sender
        self.content = content
        self.references = references
        self.timestamp = Date()
        self.isTyping = isTyping
    }
}

// MARK: - FAQ Knowledge Base Model

struct FAQEntry: Codable {
    let question: String
    let answer: String
    let category: String
    let tags: [String]
    let sources: [FAQSource]?
}

struct FAQSource: Codable {
    let title: String
    let url: String?
    let type: String
}

struct FAQFile: Codable {
    let version: Int
    let faq: [FAQEntry]
}

// MARK: - Chatbot Capability Modes

enum ChatbotCapabilityMode {
    case localKnowledge
    case aiPowered(backend: String)

    var description: String {
        switch self {
        case .localKnowledge:
            return "Local Knowledge Base"
        case .aiPowered(let backend):
            return "Enhanced with \(backend)"
        }
    }

    var isAIPowered: Bool {
        if case .aiPowered = self { return true }
        return false
    }
}

// MARK: - Chatbot Service

@MainActor
final class ChatbotService: ObservableObject {
    static let shared = ChatbotService()

    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var currentMode: ChatbotCapabilityMode = .localKnowledge

    private var faqKnowledgeBase: [FAQEntry] = []

    private init() {
        loadFAQKnowledgeBase()
        updateCapabilityMode()
    }

    // MARK: - Public API

    func sendMessage(_ text: String, context: BotanyContext? = nil) async {
        let userMessage = ChatMessage(sender: .user, content: text)
        await MainActor.run {
            messages.append(userMessage)
            isProcessing = true
        }

        updateCapabilityMode()

        var response: String
        var references: [ContentReference] = []

        // Strategy: AI backend first when available, FAQ fallback for local-only mode
        if case .aiPowered(let backend) = currentMode {
            let aiResult = await generateAIPoweredResponse(text, backend: backend, context: context)
            response = aiResult.text
            references = aiResult.references
        } else if let faqResult = findFAQMatch(for: text) {
            response = faqResult.answer
            references = faqResult.references
        } else {
            response = "I don't have a specific answer for that in my local knowledge base. Try rephrasing your question, or tap one of the suggested topics below for pre-loaded botanical information."
        }

        let finalResponse = response.isEmpty ? "I encountered an error processing your request. Please try again." : response
        let assistantMessage = ChatMessage(sender: .assistant, content: finalResponse, references: references, isTyping: true)

        await MainActor.run {
            messages.append(assistantMessage)
            isProcessing = false
        }
    }

    func updateCapabilityMode() {
        let apiKeyManager = APIKeyManager.shared

        if apiKeyManager.claudeKeyConfigured {
            currentMode = .aiPowered(backend: "Claude")
        } else if apiKeyManager.openAIKeyConfigured {
            currentMode = .aiPowered(backend: "ChatGPT")
        } else if OwnerBackendConfig.isAvailable {
            currentMode = .aiPowered(backend: "Enhanced")
        } else {
            currentMode = .localKnowledge
        }
    }

    func clearMessages() {
        messages.removeAll()
    }

    /// Get suggested quick actions based on current context
    func getSuggestedActions(for context: BotanyContext) -> [String] {
        var contextual: [String] = []

        switch context.currentScreen {
        case _ where context.currentScreen.contains("Learn"):
            contextual = [
                "What is pinnate venation?",
                "How do I identify a plant family?",
                "What leaf shapes help narrow down species?"
            ]

        case _ where context.currentScreen.contains("Botanize") || context.currentScreen.contains("Observe"):
            contextual = [
                "How do I identify this leaf shape?",
                "What features distinguish grasses?",
                "Tips for identifying trees in winter"
            ]

        case _ where context.currentScreen.contains("Capture"):
            contextual = [
                "Best photo angle for identification?",
                "Which plant parts help most with ID?",
                "Why isn't my plant being recognized?"
            ]

        case _ where context.currentScreen.contains("Journal"):
            contextual = [
                "What should I note in field observations?",
                "How do I document phenology?",
                "Best practices for plant photography"
            ]

        case _ where context.currentScreen.contains("Bloom"):
            contextual = [
                "When do magnolias bloom?",
                "What blooms in early spring?",
                "How do I record bloom observations?"
            ]

        case _ where context.currentScreen.contains("Conservation"):
            contextual = [
                "What does IUCN Endangered mean?",
                "How can I support local plant biodiversity?",
                "How do conservation statuses work?"
            ]

        default:
            contextual = []
        }

        let generalPool: [String] = [
            "What is a compound leaf?",
            "Explain alternate vs opposite leaves",
            "What is an inflorescence?",
            "How are plants classified?",
            "What are stamens and pistils?",
            "How do I press and preserve plants?",
            "What is a herbarium specimen?",
            "What is pollination?",
            "How do seeds disperse?",
            "How do I identify a tree by its bark?",
            "What leaf features help with plant ID?",
            "How do I tell grasses from sedges?",
            "What's the best way to photograph a plant for ID?",
            "How do I use a dichotomous key?",
            "What are the parts of a flower?"
        ]

        let remaining = generalPool.filter { faq in
            !contextual.contains(faq)
        }.shuffled()

        let faqSlice = Array(remaining.prefix(3))
        return contextual + faqSlice
    }

    // MARK: - Local FAQ Knowledge Base

    private func loadFAQKnowledgeBase() {
        guard let url = Bundle.main.url(forResource: "botany_faq", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(FAQFile.self, from: data) else {
            print("[Chatbot] Failed to load botany_faq.json — using empty FAQ base")
            return
        }
        faqKnowledgeBase = file.faq
        print("[Chatbot] Loaded \(file.faq.count) FAQ entries")
    }

    private struct FAQMatchResult {
        let answer: String
        let references: [ContentReference]
    }

    private func findFAQMatch(for query: String) -> FAQMatchResult? {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Exact question match
        if let exact = faqKnowledgeBase.first(where: { $0.question.lowercased() == normalizedQuery }) {
            return FAQMatchResult(answer: exact.answer, references: referencesFromFAQ(exact))
        }

        // 2. Score by keyword overlap + tags
        var bestMatch: FAQEntry?
        var bestScore: Double = 0

        let queryWords = Set(normalizedQuery.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 })

        for entry in faqKnowledgeBase {
            var score: Double = 0
            let questionWords = Set(entry.question.lowercased().components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 2 })

            let overlap = queryWords.intersection(questionWords)
            if !overlap.isEmpty {
                score += Double(overlap.count) / Double(max(queryWords.count, 1))
            }

            for tag in entry.tags {
                if normalizedQuery.contains(tag.lowercased()) {
                    score += 0.3
                }
            }

            if entry.question.lowercased().contains(normalizedQuery) {
                score += 0.5
            } else if normalizedQuery.contains(entry.question.lowercased().replacingOccurrences(of: "?", with: "")) {
                score += 0.4
            }

            if score > bestScore {
                bestScore = score
                bestMatch = entry
            }
        }

        guard bestScore >= 0.7, let match = bestMatch else {
            return nil
        }

        return FAQMatchResult(answer: match.answer, references: referencesFromFAQ(match))
    }

    private func referencesFromFAQ(_ entry: FAQEntry) -> [ContentReference] {
        var refs: [ContentReference] = []

        if let sources = entry.sources {
            for source in sources {
                let refType = ReferenceType(rawValue: source.type) ?? .faq
                refs.append(ContentReference(title: source.title, url: source.url, type: refType))
            }
        }

        // Auto-detect botanical references
        refs.append(contentsOf: BotanyReferenceParser.extractSpecies(from: entry.answer))
        refs.append(contentsOf: BotanyReferenceParser.extractFamilies(from: entry.answer))

        refs.append(ContentReference(
            title: "RadicleBotany Knowledge Base",
            type: .faq,
            detail: entry.category.replacingOccurrences(of: "_", with: " ").capitalized
        ))

        return refs
    }

    // MARK: - AI-Powered Response

    private struct AIResponseResult {
        let text: String
        let references: [ContentReference]
    }

    private func generateAIPoweredResponse(_ query: String, backend: String, context: BotanyContext?) async -> AIResponseResult {
        var contextToSend = context ?? buildCurrentContext()
        contextToSend.query = query

        // Build conversation history from recent messages (last 10) for multi-turn context
        let recentMessages = messages.suffix(10)
        let history: [[String: String]] = recentMessages.compactMap { msg in
            switch msg.sender {
            case .user: return ["role": "user", "content": msg.content]
            case .assistant: return ["role": "assistant", "content": msg.content]
            }
        }
        if !history.isEmpty {
            contextToSend.conversationHistory = history
        }

        let userTier = StoreManager.shared.userTier

        if let insight = await IntelligenceBackendService.shared.requestInsight(context: contextToSend, userTier: userTier) {
            let parsed = BotanyReferenceParser.parse(insight.message)

            var allRefs = parsed.references
            allRefs.append(contentsOf: BotanyReferenceParser.extractSpecies(from: parsed.cleanText))
            allRefs.append(contentsOf: BotanyReferenceParser.extractFamilies(from: parsed.cleanText))

            // Deduplicate by title
            var seen = Set<String>()
            allRefs = allRefs.filter { ref in
                let key = ref.title.lowercased()
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }

            if let links = insight.links {
                for link in links where !link.isEmpty {
                    let domain = URL(string: link)?.host ?? link
                    allRefs.append(ContentReference(title: domain, url: link, type: .article))
                }
            }

            return AIResponseResult(text: parsed.cleanText, references: allRefs)
        }

        return AIResponseResult(
            text: "I encountered an error connecting to the service. Please check your internet connection and try again.",
            references: []
        )
    }

    private func buildCurrentContext() -> BotanyContext {
        return BotanyContext(
            currentScreen: "Chatbot",
            recentActions: [],
            timestamp: Date(),
            query: nil
        )
    }
}

// MARK: - Chatbot Context Convenience

extension ChatbotService {
    static func contextFor(screen: String) -> BotanyContext {
        return BotanyContext(
            currentScreen: screen,
            recentActions: [],
            timestamp: Date(),
            query: nil
        )
    }
}

// MARK: - Botany Reference Parser

enum BotanyReferenceParser {

    struct ParsedResponse {
        let cleanText: String
        let references: [ContentReference]
    }

    /// Parse a response that may contain a [SOURCES] block
    static func parse(_ text: String) -> ParsedResponse {
        let sourcesPattern = #"(?:\n\n|\n)?\[SOURCES\]\n([\s\S]+?)$"#

        guard let regex = try? NSRegularExpression(pattern: sourcesPattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return ParsedResponse(cleanText: text.trimmingCharacters(in: .whitespacesAndNewlines), references: [])
        }

        let cleanRange = NSRange(location: 0, length: match.range.location)
        let cleanText = (text as NSString).substring(with: cleanRange).trimmingCharacters(in: .whitespacesAndNewlines)

        let sourcesRange = Range(match.range(at: 1), in: text)!
        let sourcesBlock = String(text[sourcesRange])
        let references = parseSourceLines(sourcesBlock)

        return ParsedResponse(cleanText: cleanText, references: references)
    }

    private static func parseSourceLines(_ block: String) -> [ContentReference] {
        let lines = block.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("• ") }

        return lines.compactMap { line in
            let content = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)

            if content.lowercased().hasPrefix("species:") {
                let title = String(content.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                return ContentReference(title: title, type: .species)
            } else if content.lowercased().hasPrefix("family:") {
                let title = String(content.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                return ContentReference(title: title, type: .family)
            } else if content.lowercased().hasPrefix("term:") {
                let title = String(content.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                return ContentReference(title: title, type: .term)
            } else if content.lowercased().hasPrefix("source:") {
                let title = String(content.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                return ContentReference(title: title, type: .article)
            } else {
                return ContentReference(title: content, type: inferType(from: content))
            }
        }
    }

    private static func inferType(from text: String) -> ReferenceType {
        let lower = text.lowercased()
        // Italicized binomials (two capitalized words)
        if text.contains(" ") && text.first?.isUppercase == true {
            let parts = text.components(separatedBy: " ")
            if parts.count >= 2 && parts[1].first?.isLowercase == true {
                return .species
            }
        }
        if lower.hasSuffix("aceae") || lower.hasSuffix("idae") { return .family }
        if lower.contains("http") { return .article }
        return .term
    }

    // MARK: - Auto-Detection from Text

    /// Extract species names (italicized binomials like *Quercus alba*)
    static func extractSpecies(from text: String) -> [ContentReference] {
        // Match "Genus species" patterns — capitalized genus + lowercase specific epithet
        let speciesPattern = #"([A-Z][a-z]+)\s+([a-z]{3,}(?:\s+(?:var\.|subsp\.)\s+[a-z]+)?)"#

        guard let regex = try? NSRegularExpression(pattern: speciesPattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var refs: [ContentReference] = []
        var seen = Set<String>()

        // Common English words that look like binomials — skip these
        let skipGenera = Set(["The", "This", "That", "These", "Those", "When", "Where", "What",
                              "Which", "While", "With", "After", "Before", "During", "Under",
                              "Over", "Some", "Many", "Most", "Each", "Every", "Both", "Keep",
                              "Make", "Take", "Give", "Have", "Been", "Being", "Note", "Also",
                              "Local", "Their", "Other", "Plant", "Flower", "Petal", "Sepal"])

        for match in matches {
            let genus = nsText.substring(with: match.range(at: 1))
            guard !skipGenera.contains(genus) else { continue }

            let fullName = nsText.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            let key = fullName.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            refs.append(ContentReference(title: fullName, type: .species))
        }

        return refs
    }

    /// Extract family names (words ending in -aceae)
    static func extractFamilies(from text: String) -> [ContentReference] {
        let familyPattern = #"([A-Z][a-z]+aceae)"#

        guard let regex = try? NSRegularExpression(pattern: familyPattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var refs: [ContentReference] = []
        var seen = Set<String>()

        for match in matches {
            let family = nsText.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            let key = family.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            refs.append(ContentReference(title: family, type: .family))
        }

        return refs
    }
}
