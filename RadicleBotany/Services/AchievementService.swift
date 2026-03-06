import Foundation
import SwiftData

/// Centralized service for checking achievement unlocks, updating study streaks, and awarding XP.
/// Stateless singleton — all state lives in SwiftData models.
@MainActor
enum AchievementService {

    // MARK: - XP Constants

    static let xpCardReviewed = 10       // "Still Learning"
    static let xpCardMastered = 25       // "Got It"
    static let xpStreakBonus = 5          // Per card when streak ≥ 3
    static let xpDeckComplete = 100       // Finish all cards in a deck
    static let xpPerfectSession = 50      // All "Got It" in a session

    // MARK: - Award XP

    /// Adds XP to the user's total and to the specific flashcard progress entry.
    static func awardXP(amount: Int, modelContext: ModelContext) {
        let settings = fetchOrCreateSettings(modelContext: modelContext)
        settings.totalXP = settings.safeTotalXP + amount
    }

    // MARK: - Study Streak

    /// Updates the study streak based on today's date vs lastStudyDate.
    /// - Same day: no-op
    /// - Yesterday: increment streak
    /// - Older or nil: reset to 1
    static func updateStudyStreak(modelContext: ModelContext) {
        let settings = fetchOrCreateSettings(modelContext: modelContext)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let lastStudy = settings.lastStudyDate {
            let lastDay = calendar.startOfDay(for: lastStudy)

            if lastDay == today {
                // Already studied today — no-op
                return
            } else if calendar.isDate(lastDay, equalTo: calendar.date(byAdding: .day, value: -1, to: today)!, toGranularity: .day) {
                // Yesterday — increment streak
                settings.studyStreakCount = settings.safeStudyStreak + 1
            } else {
                // Gap — reset streak
                settings.studyStreakCount = 1
            }
        } else {
            // First ever study
            settings.studyStreakCount = 1
        }

        settings.lastStudyDate = .now
    }

    // MARK: - Check & Unlock Achievements

    /// Scans all locked achievements with a type+threshold and unlocks any that are now met.
    /// Returns the list of newly unlocked achievements (for UI celebration).
    @discardableResult
    static func checkAndUnlock(modelContext: ModelContext) -> [Achievement] {
        let settings = fetchOrCreateSettings(modelContext: modelContext)

        // Fetch all locked achievements that have programmatic type
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> { !$0.isUnlocked && $0.achievementType != nil }
        )

        guard let lockedAchievements = try? modelContext.fetch(descriptor) else { return [] }

        // Gather current stats
        let allProgress = (try? modelContext.fetch(FetchDescriptor<FlashcardProgress>())) ?? []

        let totalReviewed = allProgress.reduce(0) { $0 + $1.reviewCount }
        let totalMastered = allProgress.filter { $0.status == "known" }.count
        let termsMastered = allProgress.filter { $0.status == "known" && ($0.deckType == nil || $0.deckType == "term") }.count
        let plantsMastered = allProgress.filter { $0.status == "known" && $0.deckType == "plant" }.count
        let familiesMastered = allProgress.filter { $0.status == "known" && $0.deckType == "family" }.count
        let currentStreak = settings.safeStudyStreak
        let currentXP = settings.safeTotalXP

        var newlyUnlocked: [Achievement] = []

        for achievement in lockedAchievements {
            guard let type = achievement.achievementType, let threshold = achievement.threshold else { continue }

            let currentValue: Int
            switch type {
            case "flashcard_cards_reviewed":
                currentValue = totalReviewed
            case "flashcard_terms_mastered":
                currentValue = termsMastered
            case "flashcard_plants_mastered":
                currentValue = plantsMastered
            case "flashcard_families_mastered":
                currentValue = familiesMastered
            case "flashcard_total_mastered":
                currentValue = totalMastered
            case "flashcard_study_streak":
                currentValue = currentStreak
            case "flashcard_xp_milestone":
                currentValue = currentXP
            // Session-based achievements are checked directly by StudySessionManager
            case "flashcard_session_perfect":
                continue
            default:
                continue
            }

            if currentValue >= threshold {
                achievement.isUnlocked = true
                achievement.unlockedDate = .now
                newlyUnlocked.append(achievement)
            }
        }

        return newlyUnlocked
    }

    // MARK: - Check Perfect Session

    /// Specifically checks and unlocks the "Perfect Session" achievement.
    /// Called by StudySessionManager when a deck is completed with 100% mastery.
    static func checkPerfectSession(modelContext: ModelContext) -> Achievement? {
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> {
                !$0.isUnlocked && $0.achievementType == "flashcard_session_perfect"
            }
        )

        guard let achievements = try? modelContext.fetch(descriptor),
              let perfect = achievements.first else { return nil }

        perfect.isUnlocked = true
        perfect.unlockedDate = .now
        return perfect
    }

    // MARK: - Helpers

    /// Fetches or creates the singleton UserSettings.
    private static func fetchOrCreateSettings(modelContext: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }
}
