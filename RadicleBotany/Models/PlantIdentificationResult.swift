import Foundation

struct PlantIdentificationResult: Codable {
    let query: Query?
    let language: String?
    let preferedReferential: String?
    let results: [PlantMatch]

    var bestMatch: PlantMatch? {
        results.first
    }
}

struct Query: Codable {
    let project: String?
    let images: [String]?
    let organs: [String]?
}

struct PlantMatch: Codable, Identifiable {
    let score: Double
    let species: Species
    let images: [RelatedImage]?

    var id: String { species.scientificNameWithoutAuthor }

    var commonName: String {
        species.commonNames?.first ?? species.scientificNameWithoutAuthor
    }

    var titleCasedCommonName: String {
        commonName.titleCased
    }

    var scientificName: String {
        species.scientificNameWithoutAuthor
    }
}

struct Species: Codable {
    let scientificNameWithoutAuthor: String
    let scientificNameAuthorship: String?
    let scientificName: String?
    let genus: TaxonInfo?
    let family: TaxonInfo?
    let commonNames: [String]?
}

struct RelatedImage: Codable, Identifiable {
    let organ: String?
    let url: RelatedImageURL?
    let citation: String?

    var id: String { url?.m ?? url?.o ?? UUID().uuidString }

    /// Best available image URL (prefer medium, fallback to original)
    var bestURL: String? { url?.m ?? url?.o }
}

struct RelatedImageURL: Codable {
    let o: String?
    let m: String?
    let s: String?
}

struct TaxonInfo: Codable {
    let scientificNameWithoutAuthor: String?
    let scientificNameAuthorship: String?
    let scientificName: String?
}
