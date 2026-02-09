import Foundation
import SwiftData

@Model
final class Observation {
    var plantScientificName: String?
    var photoData: Data?
    var latitude: Double?
    var longitude: Double?
    var date: Date
    var notes: String?
    var verifiedTraits: [String]

    init(
        plantScientificName: String? = nil,
        photoData: Data? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        date: Date = .now,
        notes: String? = nil,
        verifiedTraits: [String] = []
    ) {
        self.plantScientificName = plantScientificName
        self.photoData = photoData
        self.latitude = latitude
        self.longitude = longitude
        self.date = date
        self.notes = notes
        self.verifiedTraits = verifiedTraits
    }
}
