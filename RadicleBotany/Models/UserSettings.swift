import Foundation
import SwiftData

@Model
final class UserSettings {
    var purchasedTier: String
    var subscriptionExpirationDate: Date?
    var streakCount: Int
    var lastActiveDate: Date?
    var profileName: String?
    var profileEmail: String?
    var profilePhotoData: Data?

    // MARK: - Flashcard Gamification
    var totalXP: Int?
    var lastStudyDate: Date?
    var studyStreakCount: Int?

    // MARK: - Personalization
    var botanicalExperience: String?   // BotanicalExperience raw value
    var botanicalGoals: String?        // JSON-encoded [BotanicalGoal] raw values

    init(
        purchasedTier: String = "free",
        subscriptionExpirationDate: Date? = nil,
        streakCount: Int = 0,
        lastActiveDate: Date? = nil,
        profileName: String? = nil,
        profileEmail: String? = nil,
        profilePhotoData: Data? = nil,
        totalXP: Int? = nil,
        lastStudyDate: Date? = nil,
        studyStreakCount: Int? = nil,
        botanicalExperience: String? = nil,
        botanicalGoals: String? = nil
    ) {
        self.purchasedTier = purchasedTier
        self.subscriptionExpirationDate = subscriptionExpirationDate
        self.streakCount = streakCount
        self.lastActiveDate = lastActiveDate
        self.profileName = profileName
        self.profileEmail = profileEmail
        self.profilePhotoData = profilePhotoData
        self.totalXP = totalXP
        self.lastStudyDate = lastStudyDate
        self.studyStreakCount = studyStreakCount
        self.botanicalExperience = botanicalExperience
        self.botanicalGoals = botanicalGoals
    }

    var tier: UserTier {
        UserTier(rawValue: purchasedTier) ?? .free
    }

    // MARK: - Safe Accessors
    var safeTotalXP: Int { totalXP ?? 0 }
    var safeStudyStreak: Int { studyStreakCount ?? 0 }
}

// MARK: - User Tier

enum UserTier: String, Codable {
    case free
    case annual  // RadicleBotany — full access

    var canAccessFullContent: Bool { self != .free }
    var canAccessCapture: Bool { self != .free }
    var canAccessPlantAssistant: Bool { self != .free }
    var canAccessiCloud: Bool { self != .free }

    var displayName: String {
        switch self {
        case .free:   return "Free"
        case .annual: return "RadicleBotany"
        }
    }
}

// MARK: - Feature Gating

enum Feature {
    case fullSpeciesAccess
    case fullFamilyAccess
    case fullTermAccess
    case capture
    case bothMode
    case journal
    case collections
    case iCloudSync
    case unlimitedObserve
    case plantAssistant

    func isUnlocked(for tier: UserTier) -> Bool {
        tier.canAccessFullContent
    }
}

// MARK: - Personalization Enums

enum BotanicalExperience: String, Codable, CaseIterable {
    case novice
    case enthusiast
    case student
    case professional

    var label: String {
        switch self {
        case .novice:       return "New to botany"
        case .enthusiast:   return "Self-taught, still learning"
        case .student:      return "Studying botany"
        case .professional: return "Field work or research"
        }
    }

    var icon: String {
        switch self {
        case .novice:       return "leaf.fill"
        case .enthusiast:   return "binoculars.fill"
        case .student:      return "text.book.closed.fill"
        case .professional: return "flask.fill"
        }
    }
}

enum BotanicalGoal: String, Codable, CaseIterable {
    case identify
    case learn
    case track
    case study
    case conserve

    var label: String {
        switch self {
        case .identify: return "Identify plants in the field"
        case .learn:    return "Learn botanical terminology"
        case .track:    return "Track my observations"
        case .study:    return "Study for coursework"
        case .conserve: return "Support plant conservation"
        }
    }

    var icon: String {
        switch self {
        case .identify: return "magnifyingglass"
        case .learn:    return "book.fill"
        case .track:    return "mappin.circle.fill"
        case .study:    return "graduationcap.fill"
        case .conserve: return "globe.americas.fill"
        }
    }
}
