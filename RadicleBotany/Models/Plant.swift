import Foundation
import SwiftData

@Model
final class Plant {
    @Attribute(.unique) var scientificName: String
    var commonName: String
    var familyLatin: String
    var plantDescription: String
    var kingdom: String
    var taxonomicClass: String
    var order: String
    var genus: String
    var isFree: Bool
    var isAtRisk: Bool
    var atRiskStatus: String?

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

    // Environment
    var habitat: String?
    var soil: String?
    var growthHabit: String?

    init(
        scientificName: String,
        commonName: String,
        familyLatin: String,
        plantDescription: String,
        kingdom: String = "Plantae",
        taxonomicClass: String = "",
        order: String = "",
        genus: String = "",
        isFree: Bool = false,
        isAtRisk: Bool = false,
        atRiskStatus: String? = nil
    ) {
        self.scientificName = scientificName
        self.commonName = commonName
        self.familyLatin = familyLatin
        self.plantDescription = plantDescription
        self.kingdom = kingdom
        self.taxonomicClass = taxonomicClass
        self.order = order
        self.genus = genus
        self.isFree = isFree
        self.isAtRisk = isAtRisk
        self.atRiskStatus = atRiskStatus
    }
}

// MARK: - JSON Decoding Structure

struct PlantJSON: Codable {
    let plantNameLatin: String
    let plantNameCommon: String
    let plantKingdom: String
    let plantClass: String
    let plantOrder: String
    let plantFamily: String
    let plantGenus: String
    let plantDescription: String
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
    let environmentHabitat: String?
    let environmentSoil: String?
    let environmentGrowthHabit: String?

    enum CodingKeys: String, CodingKey {
        case plantNameLatin = "Plant_Name_Latin"
        case plantNameCommon = "Plant_Name_Common"
        case plantKingdom = "Plant_Kingdom"
        case plantClass = "Plant_Class"
        case plantOrder = "Plant_Order"
        case plantFamily = "Plant_Family"
        case plantGenus = "Plant_Genus"
        case plantDescription = "Plant_Description"
        case leafType = "Leaf_Type"
        case leafAttachment = "Leaf_Attachment"
        case leafArrangement = "Leaf_Arrangement"
        case leafShape = "Leaf_Shape"
        case leafMargin = "Leaf_Margin"
        case leafApex = "Leaf_Apex"
        case leafBase = "Leaf_Base"
        case leafVenation = "Leaf_Venation"
        case leafTexture = "Leaf_Texture"
        case leafStipules = "Leaf_Stipules"
        case stemHabit = "Stem_Habit"
        case stemStructure = "Stem_Structure"
        case stemBranching = "Stem_Branching"
        case flowerInflorescence = "Flower_Inflorescence"
        case flowerSymmetry = "Flower_Symmetry"
        case flowerPetalCount = "Flower_Petal Count"
        case flowerPetalFusion = "Flower_Petal Fusion"
        case flowerSepalPresence = "Flower_Sepal Presence"
        case flowerSepalFusion = "Flower_Sepal Fusion"
        case flowerColor = "Flower_Color"
        case flowerPosition = "Flower_Position"
        case flowerOvaryPosition = "Flower_Ovary Position"
        case flowerSexuality = "Flower_Sexuality"
        case flowerFloralPart = "Flower_Floral Part"
        case fruitType = "Fruit_Type"
        case fruitSeedTrait = "Fruit_Seed Trait"
        case rootType = "Root_Type"
        case environmentHabitat = "Environment_Habitat"
        case environmentSoil = "Environment_Soil"
        case environmentGrowthHabit = "Environment_Growth Habit"
    }
}
