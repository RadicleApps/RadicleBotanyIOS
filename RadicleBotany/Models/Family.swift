import Foundation
import SwiftData

@Model
final class Family {
    @Attribute(.unique) var familyLatin: String
    var familyEnglish: String
    var genera: String
    var order: String
    var taxonomicClass: String
    var kingdom: String
    var familyDescription: String

    // Leaf traits
    var leafType: String?
    var leafAttachment: String?
    var leafArrangement: String?
    var leafShape: String?
    var leafMargin: String?
    var leafApex: String?
    var leafBase: String?
    var leafVenation: String?
    var leafTexture: String?
    var leafStipules: String?
    var leafAdditionalTrait: String?

    // Stem traits
    var stemHabit: String?
    var stemStructure: String?
    var stemBranching: String?

    // Flower traits
    var flowerInflorescence: String?
    var flowerSymmetry: String?
    var flowerPetalCount: String?
    var flowerPetalFusion: String?
    var flowerSepalPresence: String?
    var flowerSepalFusion: String?
    var flowerColor: String?
    var flowerPosition: String?
    var flowerOvaryPosition: String?
    var flowerSexuality: String?
    var flowerFloralPart: String?

    // Fruit traits
    var fruitType: String?
    var fruitSeedTrait: String?

    // Root traits
    var rootType: String?
    var rootTrait: String?

    // Environment
    var habitat: String?
    var soil: String?
    var growthHabit: String?

    init(
        familyLatin: String,
        familyEnglish: String,
        genera: String,
        order: String,
        taxonomicClass: String,
        kingdom: String,
        familyDescription: String
    ) {
        self.familyLatin = familyLatin
        self.familyEnglish = familyEnglish
        self.genera = genera
        self.order = order
        self.taxonomicClass = taxonomicClass
        self.kingdom = kingdom
        self.familyDescription = familyDescription
    }
}

// MARK: - JSON Decoding Structure

struct FamilyJSON: Codable {
    let familyLatin: String
    let familyEnglish: String
    let genera: String
    let order: String
    let taxonomicClass: String
    let kingdom: String
    let description: String
    let leafType: String?
    let leafAttachment: String?
    let leafArrangement: String?
    let leafShape: String?
    let leafMargin: String?
    let leafApex: String?
    let leafBase: String?
    let leafVenation: String?
    let leafTexture: String?
    let leafStipules: String?
    let leafAdditionalTrait: String?
    let stemHabit: String?
    let stemStructure: String?
    let stemBranching: String?
    let flowerInflorescence: String?
    let flowerSymmetry: String?
    let flowerPetalCount: String?
    let flowerPetalFusion: String?
    let flowerSepalPresence: String?
    let flowerSepalFusion: String?
    let flowerColor: String?
    let flowerPosition: String?
    let flowerOvaryPosition: String?
    let flowerSexuality: String?
    let flowerFloralPart: String?
    let fruitType: String?
    let fruitSeedTrait: String?
    let rootType: String?
    let rootTrait: String?
    let habitat: String?
    let soil: String?
    let growthHabit: String?
}
