import Foundation
import SwiftData

@Model
final class BotanyTerm {
    var term: String
    var category: String
    var imageURL: String?
    var showPlantID: Bool
    var isFree: Bool

    init(
        term: String,
        category: String,
        imageURL: String? = nil,
        showPlantID: Bool = false,
        isFree: Bool = false
    ) {
        self.term = term
        self.category = category
        self.imageURL = imageURL
        self.showPlantID = showPlantID
        self.isFree = isFree
    }
}

// MARK: - JSON Decoding Structure

struct BotanyTermJSON: Codable {
    let term: String
    let category: String
    let imageURL: String?
    let showInPlantID: Bool

    enum CodingKeys: String, CodingKey {
        case term
        case category
        case imageURL = "image_url"
        case showInPlantID = "show_in_plant_id"
    }
}
