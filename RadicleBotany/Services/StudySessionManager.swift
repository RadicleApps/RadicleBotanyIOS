import Foundation
import SwiftData
import Observation

/// Ephemeral per-session tracker for flashcard study sessions.
/// Tracks cards reviewed, XP earned, and unlocked achievements within a single deck session.
/// Create a new instance per flashcard view session — do not persist.
@Observable
@MainActor
final class StudySessionManager {
    // MARK: - Session Stats
    private(set) var cardsReviewed: Int = 0
    private(set) var cardsMastered: Int = 0
    private(set) var cardsStillLearning: Int = 0
    private(set) var xpEarned: Int = 0
    private(set) var newlyUnlockedAchievements: [Achievement] = []
    private(set) var sessionComplete: Bool = false

    // MARK: - Record Card Review

    /// Call after each card is answered ("Got It" or "Still Learning").
    /// - Parameters:
    ///   - mastered: true if "Got It", false if "Still Learning"
    ///   - modelContext: SwiftData context for XP persistence
    func recordCardReview(mastered: Bool, modelContext: ModelContext) {
        cardsReviewed += 1

        // Base XP
        let baseXP = mastered ? AchievementService.xpCardMastered : AchievementService.xpCardReviewed

        // Streak bonus
        let settings = fetchSettings(modelContext: modelContext)
        let streakBonus = settings.safeStudyStreak >= 3 ? AchievementService.xpStreakBonus : 0

        let totalCardXP = baseXP + streakBonus

        if mastered {
            cardsMastered += 1
        } else {
            cardsStillLearning += 1
        }

        xpEarned += totalCardXP
        AchievementService.awardXP(amount: totalCardXP, modelContext: modelContext)
    }

    // MARK: - Complete Deck

    /// Call when the user finishes all cards in the deck.
    /// Awards deck completion bonus, perfect session bonus, updates streak, and checks achievements.
    func completeDeck(modelContext: ModelContext) {
        guard !sessionComplete else { return }
        sessionComplete = true

        // Deck completion bonus
        xpEarned += AchievementService.xpDeckComplete
        AchievementService.awardXP(amount: AchievementService.xpDeckComplete, modelContext: modelContext)

        // Perfect session bonus (all mastered, at least 1 card)
        let isPerfect = cardsReviewed > 0 && cardsStillLearning == 0
        if isPerfect {
            xpEarned += AchievementService.xpPerfectSession
            AchievementService.awardXP(amount: AchievementService.xpPerfectSession, modelContext: modelContext)
        }

        // Update study streak
        AchievementService.updateStudyStreak(modelContext: modelContext)

        // Check perfect session achievement
        if isPerfect, let perfectAchievement = AchievementService.checkPerfectSession(modelContext: modelContext) {
            newlyUnlockedAchievements.append(perfectAchievement)
        }

        // Check all threshold-based achievements
        let unlocked = AchievementService.checkAndUnlock(modelContext: modelContext)
        newlyUnlockedAchievements.append(contentsOf: unlocked)
    }

    // MARK: - Helpers

    private func fetchSettings(modelContext: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        return (try? modelContext.fetch(descriptor).first) ?? UserSettings()
    }
}
