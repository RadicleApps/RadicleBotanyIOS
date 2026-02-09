import Foundation
import SwiftData

@Model
final class BotanyTerm {
    var term: String
    var category: String
    var descriptionShort: String
    var descriptionLong: String
    var imageURL: String?
    var showPlantID: Bool
    var isFree: Bool

    init(
        term: String,
        category: String,
        descriptionShort: String = "",
        descriptionLong: String = "",
        imageURL: String? = nil,
        showPlantID: Bool = false,
        isFree: Bool = false
    ) {
        self.term = term
        self.category = category
        self.descriptionShort = descriptionShort
        self.descriptionLong = descriptionLong
        self.imageURL = imageURL
        self.showPlantID = showPlantID
        self.isFree = isFree
    }
}

// MARK: - JSON Decoding Structure

struct BotanyTermJSON: Codable {
    let term: String
    let category: String
    let descriptionShort: String?
    let descriptionLong: String?
    let imageURL: String?
    let showPlantID: Bool
    let isFree: Bool?
}
