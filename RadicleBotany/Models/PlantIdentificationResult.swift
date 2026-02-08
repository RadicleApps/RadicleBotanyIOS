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

    var id: String { species.scientificNameWithoutAuthor }

    var commonName: String {
        species.commonNames?.first ?? species.scientificNameWithoutAuthor
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

struct TaxonInfo: Codable {
    let scientificNameWithoutAuthor: String?
    let scientificNameAuthorship: String?
    let scientificName: String?
}
