import Foundation
import SwiftUI
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
    var imageURL: String?

    // Additional common names from PlantNet species database
    var alternativeCommonNames: String?

    // Organ-specific images (from PlantNet)
    var leafImageURL: String?
    var flowerImageURL: String?
    var fruitImageURL: String?
    var barkImageURL: String?
    var stemImageURL: String?
    var habitImageURL: String?

    // Persistently cached image data (downloaded from best available URL)
    // This ensures every plant ALWAYS has an image, even when offline or APIs fail.
    @Attribute(.externalStorage) var cachedImageData: Data?

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

    // Bloom/Fruit timing (comma-separated month numbers, e.g. "4,5" for April–May)
    var bloomMonths: String?
    var fruitMonths: String?

    // GBIF species ID (from PlantNet enrichment, used for Tier 2 image fetching)
    var gbifId: Int?

    /// Returns the common name in Title Case (e.g., "desert sand verbena" → "Desert Sand Verbena").
    var titleCasedCommonName: String {
        commonName.titleCased
    }

    /// Returns the best available image URL — checks organ images first, then general imageURL.
    var bestImageURL: String? {
        // Prefer flower, then habit, then leaf, then general
        flowerImageURL ?? habitImageURL ?? leafImageURL ?? imageURL ?? fruitImageURL ?? barkImageURL ?? stemImageURL
    }

    /// Returns a small square thumbnail URL (75×75) for tiny previews only.
    /// Derives from bestImageURL by swapping iNaturalist's `/medium.` to `/square.`.
    /// Falls back to the full URL for non-iNaturalist sources.
    var thumbnailURL: String? {
        guard let url = bestImageURL else { return nil }
        if url.contains("/medium.") {
            return url.replacingOccurrences(of: "/medium.", with: "/square.")
        }
        return url
    }

    /// Returns a large-resolution image URL (~1024px) for hero/detail views.
    /// Swaps iNaturalist `/medium.` to `/large.` for Retina-sharp rendering.
    /// Falls back to the original URL for non-iNaturalist sources.
    var largeImageURL: String? {
        guard let url = bestImageURL else { return nil }
        if url.contains("/medium.") {
            return url.replacingOccurrences(of: "/medium.", with: "/large.")
        }
        return url
    }

    // MARK: - In-Memory Image Cache (NSCache)
    // Prevents repeated JPEG decoding from @externalStorage on every view render.
    // Key includes data size so thumbnail → full-size upgrades invalidate automatically.
    private static let _imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200 // ~200 decoded images in memory, auto-evicts under pressure
        return cache
    }()

    /// Returns a decoded UIImage from cache (instant) or decodes once from stored data.
    /// Uses NSCache so subsequent accesses never re-decode JPEG data.
    var cachedImage: UIImage? {
        guard let data = cachedImageData else { return nil }
        let key = "\(scientificName)_\(data.count)" as NSString
        if let cached = Plant._imageCache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        Plant._imageCache.setObject(image, forKey: key)
        return image
    }

    /// Whether this plant has a cached fallback image stored locally.
    var hasCachedImage: Bool {
        cachedImageData != nil
    }

    /// Whether the cached image is full-size (not a bundled small/thumbnail).
    /// Bundled small images (240px) are ~15-40 KB; network-fetched large images are 50 KB+.
    var hasFullSizeCachedImage: Bool {
        guard let data = cachedImageData else { return false }
        return data.count > 50_000
    }

    /// Returns (image, isFullSize) reading @externalStorage only ONCE.
    /// Grid cells use this instead of separate cachedImage + hasFullSizeCachedImage
    /// to avoid double file I/O on each render. Returns nil if no cached data.
    var cachedImageInfo: (image: UIImage, isFullSize: Bool)? {
        guard let data = cachedImageData else { return nil }
        let isFullSize = data.count > 50_000
        let key = "\(scientificName)_\(data.count)" as NSString
        if let cached = Plant._imageCache.object(forKey: key) {
            return (cached, isFullSize)
        }
        guard let image = UIImage(data: data) else { return nil }
        Plant._imageCache.setObject(image, forKey: key)
        return (image, isFullSize)
    }

    /// Returns an image URL for a specific organ category, or nil.
    func imageURL(for organ: PlantOrgan) -> String? {
        switch organ {
        case .leaf: return leafImageURL
        case .flower: return flowerImageURL
        case .fruit: return fruitImageURL
        case .bark: return barkImageURL
        case .stem: return stemImageURL
        case .habit: return habitImageURL
        case .root, .habitat: return nil  // No image for root/habitat (text-only traits)
        }
    }

    /// Sets an image URL for a specific organ category.
    func setImageURL(_ url: String?, for organ: PlantOrgan) {
        switch organ {
        case .leaf: leafImageURL = url
        case .flower: flowerImageURL = url
        case .fruit: fruitImageURL = url
        case .bark: barkImageURL = url
        case .stem: stemImageURL = url
        case .habit: habitImageURL = url
        case .root, .habitat: break  // No image storage for root/habitat
        }
    }

    /// All common names including alternatives from PlantNet.
    var allCommonNames: [String] {
        var names = [commonName]
        if let alt = alternativeCommonNames, !alt.isEmpty {
            names.append(contentsOf: alt.components(separatedBy: ", "))
        }
        return names
    }

    /// Returns all organ images that have been populated.
    var organImages: [(organ: PlantOrgan, url: String)] {
        PlantOrgan.imageOrgans.compactMap { organ in
            guard let url = imageURL(for: organ), !url.isEmpty else { return nil }
            return (organ, url)
        }
    }

    // MARK: - Bloom/Fruit Computed Helpers

    /// Returns bloom months as an array of integers (1–12).
    var bloomMonthArray: [Int] {
        guard let bloomMonths, !bloomMonths.isEmpty else { return [] }
        return bloomMonths.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Returns fruit months as an array of integers (1–12).
    var fruitMonthArray: [Int] {
        guard let fruitMonths, !fruitMonths.isEmpty else { return [] }
        return fruitMonths.components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Human-readable bloom period string (e.g., "April – May").
    var bloomPeriodText: String? {
        let months = bloomMonthArray
        guard !months.isEmpty else { return nil }
        let formatter = DateFormatter()
        let names = months.compactMap { m -> String? in
            guard (1...12).contains(m) else { return nil }
            return formatter.monthSymbols[m - 1]
        }
        guard !names.isEmpty else { return nil }
        if names.count <= 2 {
            return names.joined(separator: " – ")
        }
        return "\(names.first!) – \(names.last!)"
    }

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
        atRiskStatus: String? = nil,
        imageURL: String? = nil
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
        self.imageURL = imageURL
    }
}

// MARK: - Plant Organ Types

/// Plant organ categories matching PlantNet's media classification.
/// Maps to RadicleBotany's trait sections.
enum PlantOrgan: String, CaseIterable, Codable, Identifiable {
    case leaf = "Leaf"
    case stem = "Stem"
    case flower = "Flower"
    case fruit = "Fruit"
    case root = "Root"
    case bark = "Bark"
    case habit = "Habit"
    case habitat = "Habitat"

    var id: String { rawValue }

    /// Display name for UI (same as rawValue)
    var displayName: String { rawValue }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .leaf: return "leaf.fill"
        case .stem: return "laurel.leading"
        case .flower: return "camera.macro"
        case .fruit: return "drop.fill"
        case .root: return "carrot.fill"
        case .bark: return "tree.fill"
        case .habit: return "tree.fill"
        case .habitat: return "mountain.2.fill"
        }
    }

    /// Accent color for this organ
    var color: Color {
        switch self {
        case .leaf: return .greenSecondary
        case .stem: return .greenLight
        case .flower: return .orangePrimary
        case .fruit: return .warningAmber
        case .root: return .orangeLight
        case .bark: return .orangeLight
        case .habit: return .purpleSecondary
        case .habitat: return .purpleSecondary
        }
    }

    /// Organs that have associated images (excludes habitat which is text-only)
    static var imageOrgans: [PlantOrgan] {
        [.leaf, .stem, .flower, .fruit, .bark, .habit]
    }

    /// Maps PlantNet API organ strings to our enum
    static func from(plantNetOrgan: String) -> PlantOrgan? {
        switch plantNetOrgan.lowercased() {
        case "leaf": return .leaf
        case "flower": return .flower
        case "fruit": return .fruit
        case "bark": return .bark
        case "branch": return .stem
        case "habit": return .habit
        default: return nil
        }
    }

    /// Trait questions for each organ, mapped to the Plant model's property names.
    var traitQuestions: [TraitQuestion] {
        switch self {
        case .leaf:
            return [
                TraitQuestion(title: "Leaf Type", category: "Leaf Type", keyPath: \.leafType),
                TraitQuestion(title: "Leaf Shape", category: "Leaf Shape", keyPath: \.leafShape),
                TraitQuestion(title: "Leaf Arrangement", category: "Leaf Arrangement", keyPath: \.leafArrangement),
                TraitQuestion(title: "Leaf Attachment", category: "Leaf Attachment", keyPath: \.leafAttachment),
                TraitQuestion(title: "Leaf Margin", category: "Leaf Margin", keyPath: \.leafMargin),
                TraitQuestion(title: "Leaf Apex", category: "Leaf Apex", keyPath: \.leafApex),
                TraitQuestion(title: "Leaf Base", category: "Leaf Base", keyPath: \.leafBase),
                TraitQuestion(title: "Leaf Venation", category: "Leaf Venation", keyPath: \.leafVenation),
                TraitQuestion(title: "Leaf Texture", category: "Surface Texture", keyPath: \.leafTexture),
                TraitQuestion(title: "Stipules", category: "Stipule Arrangement", keyPath: \.leafStipules)
            ]
        case .stem:
            return [
                TraitQuestion(title: "Stem Habit", category: "Stem Morphology", keyPath: \.stemHabit),
                TraitQuestion(title: "Stem Structure", category: "Stem Morphology", keyPath: \.stemStructure),
                TraitQuestion(title: "Stem Branching", category: "Stem Morphology", keyPath: \.stemBranching)
            ]
        case .flower:
            return [
                TraitQuestion(title: "Flower Color", category: "Petal Color", keyPath: \.flowerColor),
                TraitQuestion(title: "Flower Symmetry", category: "Floral Symmetry", keyPath: \.flowerSymmetry),
                TraitQuestion(title: "Petal Count", category: "Petal Count", keyPath: \.flowerPetalCount),
                TraitQuestion(title: "Petal Fusion", category: "Petal Fusion", keyPath: \.flowerPetalFusion),
                TraitQuestion(title: "Sepal Presence", category: "Sepal Presence", keyPath: \.flowerSepalPresence),
                TraitQuestion(title: "Sepal Fusion", category: "Sepal Fusion", keyPath: \.flowerSepalFusion),
                TraitQuestion(title: "Inflorescence", category: "Inflorescence Type", keyPath: \.flowerInflorescence),
                TraitQuestion(title: "Flower Position", category: "Flower Position", keyPath: \.flowerPosition),
                TraitQuestion(title: "Ovary Position", category: "Ovary Position", keyPath: \.flowerOvaryPosition),
                TraitQuestion(title: "Floral Sex", category: "Floral Sex", keyPath: \.flowerSexuality),
                TraitQuestion(title: "Floral Part", category: "Floral Part", keyPath: \.flowerFloralPart)
            ]
        case .fruit:
            return [
                TraitQuestion(title: "Fruit Type", category: "Fruit Type", keyPath: \.fruitType),
                TraitQuestion(title: "Seed Trait", category: "Seed Trait", keyPath: \.fruitSeedTrait)
            ]
        case .root:
            return [
                TraitQuestion(title: "Root Type", category: "Root Type", keyPath: \.rootType)
            ]
        case .bark:
            return []
        case .habit:
            return [
                TraitQuestion(title: "Growth Habit", category: "Growth Habit", keyPath: \.stemHabit)
            ]
        case .habitat:
            return [
                TraitQuestion(title: "Habitat", category: "Habitat", keyPath: \.habitat)
            ]
        }
    }
}

// MARK: - Trait Question

struct TraitQuestion: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let keyPath: KeyPath<Plant, String?>
}

// MARK: - JSON Decoding Structure

// MARK: - Title Case String Extension

extension String {
    /// Converts a string to Title Case, preserving common botanical lowercase words.
    /// "desert sand verbena" → "Desert Sand Verbena"
    /// Words always lowercase (unless first): of, the, and, in, on, at, for, with, a, an
    var titleCased: String {
        let lowercaseWords: Set<String> = ["of", "the", "and", "in", "on", "at", "for", "with", "a", "an"]
        let words = self.components(separatedBy: " ")
        return words.enumerated().map { index, word in
            guard !word.isEmpty else { return word }
            if index > 0 && lowercaseWords.contains(word.lowercased()) {
                return word.lowercased()
            }
            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}

struct PlantJSON: Codable {
    let plantNameLatin: String
    let plantNameCommon: String
    let plantKingdom: String?
    let plantClass: String?
    let plantOrder: String?
    let plantFamily: String?
    let plantGenus: String?
    let plantDescription: String?
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
    let bloomMonths: String?
    let fruitMonths: String?

    // Pre-baked image URLs (exported from iNaturalist via scripts/export_image_urls.py)
    let imageURL: String?
    let flowerImageURL: String?
    let leafImageURL: String?
    let fruitImageURL: String?
    let barkImageURL: String?
    let stemImageURL: String?
    let habitImageURL: String?
    let gbifId: Int?

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
        case bloomMonths = "Bloom_Months"
        case fruitMonths = "Fruit_Months"
        case imageURL = "image_url"
        case flowerImageURL = "flower_image_url"
        case leafImageURL = "leaf_image_url"
        case fruitImageURL = "fruit_image_url"
        case barkImageURL = "bark_image_url"
        case stemImageURL = "stem_image_url"
        case habitImageURL = "habit_image_url"
        case gbifId = "gbif_id"
    }
}
