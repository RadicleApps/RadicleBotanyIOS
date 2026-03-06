import Foundation
import SwiftUI
import SwiftData

enum LinkedEntityType: String, Codable, CaseIterable {
    case plant
    case family
    case term
    case observation

    var displayName: String {
        switch self {
        case .plant: return "Plant"
        case .family: return "Family"
        case .term: return "Term"
        case .observation: return "Observation"
        }
    }

    var icon: String {
        switch self {
        case .plant: return "leaf.fill"
        case .family: return "leaf.circle.fill"
        case .term: return "text.book.closed.fill"
        case .observation: return "camera.fill"
        }
    }

    var color: Color {
        switch self {
        case .plant: return .greenSecondary
        case .family: return .purpleSecondary
        case .term: return .orangePrimary
        case .observation: return .orangeLight
        }
    }
}

@Model
final class JournalNote {
    var title: String
    var content: String
    var date: Date
    var linkedEntityType: String?
    var linkedEntityID: String?

    init(
        title: String = "",
        content: String = "",
        date: Date = .now,
        linkedEntityType: String? = nil,
        linkedEntityID: String? = nil
    ) {
        self.title = title
        self.content = content
        self.date = date
        self.linkedEntityType = linkedEntityType
        self.linkedEntityID = linkedEntityID
    }

    // MARK: - Convenience

    var entityType: LinkedEntityType? {
        guard let raw = linkedEntityType else { return nil }
        return LinkedEntityType(rawValue: raw)
    }

    var hasLink: Bool {
        linkedEntityType != nil && linkedEntityID != nil
    }

    var displayTitle: String {
        title.isEmpty ? "Untitled Note" : title
    }

    var contentPreview: String {
        if content.isEmpty { return "No content" }
        let trimmed = content.prefix(120)
        return String(trimmed)
    }
}
