import Foundation

/// Rate Limit Manager — Controls owner-backend query usage per user per day.
///
/// Tiered limits protect the owner's API budget:
/// - Free: 20 queries/day (casual use)
/// - Annual: 100 queries/day (power users)
/// - Path: Unlimited (premium workflows)
///
/// Resets daily at midnight local time. Persisted in UserDefaults.

final class RateLimitManager {
    static let shared = RateLimitManager()

    private static let countKey = "radiclebotany_owner_query_count"
    private static let dateKey = "radiclebotany_owner_query_date"

    private init() {}

    // MARK: - Tier Limits

    /// Daily query limit for a given user tier
    func dailyLimit(for tier: UserTier) -> Int {
        switch tier {
        case .free: return 20
        case .annual: return 100
        case .path: return Int.max
        }
    }

    // MARK: - Query Tracking

    /// Check if the user can make another owner-backend query
    func canQuery(tier: UserTier) -> Bool {
        resetIfNewDay()
        let count = currentDayCount()
        return count < dailyLimit(for: tier)
    }

    /// Record a query and return the remaining count
    @discardableResult
    func recordQuery(tier: UserTier) -> Int {
        resetIfNewDay()
        let newCount = currentDayCount() + 1
        UserDefaults.standard.set(newCount, forKey: Self.countKey)
        return max(0, dailyLimit(for: tier) - newCount)
    }

    /// Current queries used today
    func queriesUsedToday() -> Int {
        resetIfNewDay()
        return currentDayCount()
    }

    /// Remaining queries for the day
    func remainingQueries(tier: UserTier) -> Int {
        resetIfNewDay()
        return max(0, dailyLimit(for: tier) - currentDayCount())
    }

    // MARK: - Internal

    private func currentDayCount() -> Int {
        return UserDefaults.standard.integer(forKey: Self.countKey)
    }

    /// Reset counter if we've crossed into a new calendar day
    private func resetIfNewDay() {
        let stored = UserDefaults.standard.object(forKey: Self.dateKey) as? Date
        let calendar = Calendar.current

        if let stored = stored, calendar.isDateInToday(stored) {
            return
        }

        UserDefaults.standard.set(0, forKey: Self.countKey)
        UserDefaults.standard.set(Date(), forKey: Self.dateKey)
    }
}
