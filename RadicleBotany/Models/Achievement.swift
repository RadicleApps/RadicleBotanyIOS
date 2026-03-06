import Foundation
import SwiftData

@Model
final class Achievement {
    var name: String
    var achievementDescription: String
    var category: String
    var isUnlocked: Bool
    var unlockedDate: Date?
    /// Programmatic type for achievement checking (e.g. "flashcard_terms_mastered")
    var achievementType: String?
    /// Threshold value for programmatic unlock (e.g. 50, 7, 500)
    var threshold: Int?

    init(
        name: String,
        achievementDescription: String,
        category: String,
        isUnlocked: Bool = false,
        unlockedDate: Date? = nil,
        achievementType: String? = nil,
        threshold: Int? = nil
    ) {
        self.name = name
        self.achievementDescription = achievementDescription
        self.category = category
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
        self.achievementType = achievementType
        self.threshold = threshold
    }
}
