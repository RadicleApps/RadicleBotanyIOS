import Foundation
import SwiftData

@Model
final class Achievement {
    var name: String
    var achievementDescription: String
    var category: String
    var isUnlocked: Bool
    var unlockedDate: Date?

    init(
        name: String,
        achievementDescription: String,
        category: String,
        isUnlocked: Bool = false,
        unlockedDate: Date? = nil
    ) {
        self.name = name
        self.achievementDescription = achievementDescription
        self.category = category
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
    }
}
