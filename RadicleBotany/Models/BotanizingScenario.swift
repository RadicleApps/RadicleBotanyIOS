import Foundation
import SwiftUI

// MARK: - Scenario Models (Codable from Botanizing.json)

struct BotanizingScenario: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let difficulty: String
    let estimatedMinutes: Int
    let icon: String
    let startNodeId: String
    let nodes: [String: BotanizingNode]

    var difficultyLevel: ScenarioDifficulty {
        ScenarioDifficulty(rawValue: difficulty) ?? .beginner
    }

    var categoryType: ScenarioCategory {
        ScenarioCategory(rawValue: category) ?? .identification
    }

    var nodeCount: Int {
        nodes.values.filter { $0.choices != nil }.count
    }
}

struct BotanizingNode: Codable {
    let narrative: String?
    let hint: String?
    let choices: [BotanizingChoice]?
    let outcome: BotanizingOutcome?

    var isTerminal: Bool { outcome != nil }
}

struct BotanizingChoice: Codable, Identifiable {
    let id: String
    let text: String
    let nextNodeId: String
    let quality: String

    var qualityLevel: ChoiceQuality {
        ChoiceQuality(rawValue: quality) ?? .acceptable
    }
}

struct BotanizingOutcome: Codable {
    let grade: String
    let title: String
    let summary: String
    let keyLessons: [String]
    let relatedTerms: [String]?

    var gradeLevel: OutcomeGrade {
        OutcomeGrade(rawValue: grade) ?? .good
    }
}

// MARK: - Enums

enum ScenarioCategory: String, CaseIterable {
    case identification = "Identification"
    case safety = "Safety"
    case habitat = "Habitat"
    case seasonal = "Seasonal"
    case morphology = "Morphology"

    var icon: String {
        switch self {
        case .identification: return "magnifyingglass"
        case .safety: return "exclamationmark.shield.fill"
        case .habitat: return "mountain.2.fill"
        case .seasonal: return "calendar.badge.clock"
        case .morphology: return "leaf.fill"
        }
    }

    var label: String { rawValue }
}

enum ScenarioDifficulty: String, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var color: Color {
        switch self {
        case .beginner: return AppColors.success
        case .intermediate: return AppColors.primaryAmber
        case .advanced: return AppColors.error
        }
    }
}

enum ChoiceQuality: String, Codable {
    case optimal
    case acceptable
    case poor
    case dangerous
}

enum OutcomeGrade: String, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var color: Color {
        switch self {
        case .excellent: return AppColors.success
        case .good: return AppColors.primaryAmber
        case .fair: return AppColors.warning
        case .poor: return AppColors.error
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "minus.circle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }

    var message: String {
        switch self {
        case .excellent: return "Outstanding Field Work"
        case .good: return "Solid Observation Skills"
        case .fair: return "Room to Grow"
        case .poor: return "Keep Practicing"
        }
    }
}

// MARK: - Path Tracking

struct ScenarioPathStep {
    let nodeId: String
    let choiceText: String
    let quality: ChoiceQuality
}

// MARK: - Data Loader

final class BotanizingDataLoader {
    static let shared = BotanizingDataLoader()

    private var cachedScenarios: [BotanizingScenario]?

    func loadScenarios() -> [BotanizingScenario] {
        if let cached = cachedScenarios { return cached }

        guard let url = Bundle.main.url(forResource: "Botanizing", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[BotanizingDataLoader] Botanizing.json not found in bundle")
            return []
        }

        do {
            let scenarios = try JSONDecoder().decode([BotanizingScenario].self, from: data)
            cachedScenarios = scenarios
            return scenarios
        } catch {
            print("[BotanizingDataLoader] JSON decode error: \(error)")
            return []
        }
    }
}
