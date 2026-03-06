import Foundation
import SwiftData

@Model
final class FlashcardProgress {
    var termName: String
    var status: String
    var lastReviewedDate: Date
    var reviewCount: Int
    /// Deck type: "term" (default), "family", or "plant"
    var deckType: String?
    /// Total XP earned from this card
    var xpEarned: Int?

    init(
        termName: String,
        status: String = "learning",
        lastReviewedDate: Date = .now,
        reviewCount: Int = 0,
        deckType: String? = nil,
        xpEarned: Int? = nil
    ) {
        self.termName = termName
        self.status = status
        self.lastReviewedDate = lastReviewedDate
        self.reviewCount = reviewCount
        self.deckType = deckType
        self.xpEarned = xpEarned
    }

    var safeXPEarned: Int { xpEarned ?? 0 }

    /// Convenience computed property for type-safe status access
    var studyStatus: StudyStatus {
        get { StudyStatus(rawValue: status) ?? .learning }
        set { status = newValue.rawValue }
    }

    enum StudyStatus: String {
        case learning
        case known
    }
}
