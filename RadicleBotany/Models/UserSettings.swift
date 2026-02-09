import Foundation
import SwiftData

@Model
final class UserSettings {
    var purchasedTier: String
    var subscriptionExpirationDate: Date?
    var streakCount: Int
    var lastActiveDate: Date?

    init(
        purchasedTier: String = "free",
        subscriptionExpirationDate: Date? = nil,
        streakCount: Int = 0,
        lastActiveDate: Date? = nil
    ) {
        self.purchasedTier = purchasedTier
        self.subscriptionExpirationDate = subscriptionExpirationDate
        self.streakCount = streakCount
        self.lastActiveDate = lastActiveDate
    }

    var tier: UserTier {
        UserTier(rawValue: purchasedTier) ?? .free
    }
}

// MARK: - User Tier

enum UserTier: String, Codable {
    case free
    case lifetime
    case pro

    var canAccessFullContent: Bool {
        self != .free
    }

    var canUseCapture: Bool {
        self == .pro || self == .lifetime
    }

    var canUseiCloud: Bool {
        self == .pro
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .lifetime: return "Lifetime"
        case .pro: return "Pro"
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

    func isUnlocked(for tier: UserTier) -> Bool {
        switch self {
        case .fullSpeciesAccess, .fullFamilyAccess, .fullTermAccess,
             .journal, .collections:
            return tier.canAccessFullContent
        case .capture, .bothMode, .iCloudSync:
            return tier.canUseCapture
        case .unlimitedObserve:
            return tier.canAccessFullContent
        }
    }
}
