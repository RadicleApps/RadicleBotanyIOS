import Foundation
import SwiftData

final class DataLoader {

    static let shared = DataLoader()
    private init() {}

    private let dataLoadedKey = "com.radicle.radiclebotany.dataLoaded"
    private let dataVersionKey = "com.radicle.radiclebotany.dataVersion"
    private let currentDataVersion = 2

    // MARK: - Main Load

    @MainActor
    func loadAllDataIfNeeded(modelContext: ModelContext) {
        print("[DataLoader] ========== STARTING DATA LOAD ==========")

        // With in-memory storage, check if data is already loaded this session
        let plantCount = (try? modelContext.fetchCount(FetchDescriptor<Plant>())) ?? 0
        print("[DataLoader] Current plant count in DB: \(plantCount)")

        if plantCount > 0 {
            print("[DataLoader] ✅ Data already in memory (\(plantCount) plants). Skipping.")
            return
        }

        // Load fresh data — in-memory store starts empty each launch
        loadFreshData(modelContext: modelContext)
    }

    @MainActor
    private func loadFreshData(modelContext: ModelContext) {
        print("[DataLoader] Loading data from JSON files...")
        let startTime = Date()

        loadPlants(modelContext: modelContext)
        loadFamilies(modelContext: modelContext)
        loadBotanyTerms(modelContext: modelContext)
        createDefaultUserSettings(modelContext: modelContext)
        seedAchievements(modelContext: modelContext)

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: dataLoadedKey)
            UserDefaults.standard.set(currentDataVersion, forKey: dataVersionKey)
            let elapsed = Date().timeIntervalSince(startTime)
            let finalCount = (try? modelContext.fetchCount(FetchDescriptor<Plant>())) ?? 0
            let familyCount = (try? modelContext.fetchCount(FetchDescriptor<Family>())) ?? 0
            let termCount = (try? modelContext.fetchCount(FetchDescriptor<BotanyTerm>())) ?? 0
            print("[DataLoader] ✅ All data loaded and saved in \(String(format: "%.2f", elapsed))s")
            print("[DataLoader]    Plants: \(finalCount), Families: \(familyCount), Terms: \(termCount)")
        } catch {
            print("[DataLoader] ❌ Failed to save data: \(error)")
            print("[DataLoader] ❌ Error details: \(String(describing: error))")
        }
    }

    // MARK: - Plants

    private func loadPlants(modelContext: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Plants", withExtension: "json") else {
            print("[DataLoader] Plants.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PlantJSON].self, from: data)
            print("[DataLoader] Decoded \(decoded.count) plants")

            // First 30 species are free
            for (index, json) in decoded.enumerated() {
                let plant = Plant(
                    scientificName: json.plantNameLatin,
                    commonName: json.plantNameCommon,
                    familyLatin: json.plantFamily,
                    plantDescription: json.plantDescription,
                    kingdom: json.plantKingdom,
                    taxonomicClass: json.plantClass,
                    order: json.plantOrder,
                    genus: json.plantGenus,
                    isFree: index < 30,
                    isAtRisk: false,
                    atRiskStatus: nil
                )

                // Leaf traits
                plant.leafType = json.leafType
                plant.leafAttachment = json.leafAttachment
                plant.leafArrangement = json.leafArrangement
                plant.leafShape = json.leafShape
                plant.leafMargin = json.leafMargin
                plant.leafApex = json.leafApex
                plant.leafBase = json.leafBase
                plant.leafVenation = json.leafVenation
                plant.leafTexture = json.leafTexture
                plant.leafStipules = json.leafStipules

                // Stem traits
                plant.stemHabit = json.stemHabit
                plant.stemStructure = json.stemStructure
                plant.stemBranching = json.stemBranching

                // Flower traits
                plant.flowerInflorescence = json.flowerInflorescence
                plant.flowerSymmetry = json.flowerSymmetry
                plant.flowerPetalCount = json.flowerPetalCount
                plant.flowerPetalFusion = json.flowerPetalFusion
                plant.flowerSepalPresence = json.flowerSepalPresence
                plant.flowerSepalFusion = json.flowerSepalFusion
                plant.flowerColor = json.flowerColor
                plant.flowerPosition = json.flowerPosition
                plant.flowerOvaryPosition = json.flowerOvaryPosition
                plant.flowerSexuality = json.flowerSexuality
                plant.flowerFloralPart = json.flowerFloralPart

                // Fruit traits
                plant.fruitType = json.fruitType
                plant.fruitSeedTrait = json.fruitSeedTrait

                // Root traits
                plant.rootType = json.rootType

                // Environment
                plant.habitat = json.environmentHabitat
                plant.soil = json.environmentSoil
                plant.growthHabit = json.environmentGrowthHabit

                modelContext.insert(plant)
            }
        } catch {
            print("[DataLoader] Failed to load Plants.json: \(error)")
        }
    }

    // MARK: - Families

    private func loadFamilies(modelContext: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Families", withExtension: "json") else {
            print("[DataLoader] Families.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([FamilyJSON].self, from: data)
            print("[DataLoader] Decoded \(decoded.count) families")

            for json in decoded {
                let family = Family(
                    familyLatin: json.familyLatin,
                    familyEnglish: json.familyEnglish,
                    genera: json.genera,
                    order: json.order,
                    taxonomicClass: json.taxonomicClass,
                    kingdom: json.kingdom,
                    familyDescription: json.description
                )

                // Leaf traits
                family.leafType = json.leafType
                family.leafAttachment = json.leafAttachment
                family.leafArrangement = json.leafArrangement
                family.leafShape = json.leafShape
                family.leafMargin = json.leafMargin
                family.leafApex = json.leafApex
                family.leafBase = json.leafBase
                family.leafVenation = json.leafVenation
                family.leafTexture = json.leafTexture
                family.leafStipules = json.leafStipules
                family.leafAdditionalTrait = json.leafAdditionalTrait

                // Stem traits
                family.stemHabit = json.stemHabit
                family.stemStructure = json.stemStructure
                family.stemBranching = json.stemBranching

                // Flower traits
                family.flowerInflorescence = json.flowerInflorescence
                family.flowerSymmetry = json.flowerSymmetry
                family.flowerPetalCount = json.flowerPetalCount
                family.flowerPetalFusion = json.flowerPetalFusion
                family.flowerSepalPresence = json.flowerSepalPresence
                family.flowerSepalFusion = json.flowerSepalFusion
                family.flowerColor = json.flowerColor
                family.flowerPosition = json.flowerPosition
                family.flowerOvaryPosition = json.flowerOvaryPosition
                family.flowerSexuality = json.flowerSexuality
                family.flowerFloralPart = json.flowerFloralPart

                // Fruit traits
                family.fruitType = json.fruitType
                family.fruitSeedTrait = json.fruitSeedTrait

                // Root traits
                family.rootType = json.rootType
                family.rootTrait = json.rootTrait

                // Environment
                family.habitat = json.habitat
                family.soil = json.soil
                family.growthHabit = json.growthHabit

                modelContext.insert(family)
            }
        } catch {
            print("[DataLoader] Failed to load Families.json: \(error)")
        }
    }

    // MARK: - Botany Terms

    private func loadBotanyTerms(modelContext: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Botany", withExtension: "json") else {
            print("[DataLoader] Botany.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([BotanyTermJSON].self, from: data)
            print("[DataLoader] Decoded \(decoded.count) botany terms")

            for json in decoded {
                let term = BotanyTerm(
                    term: json.term,
                    category: json.category,
                    descriptionShort: json.descriptionShort ?? "",
                    descriptionLong: json.descriptionLong ?? "",
                    imageURL: json.imageURL,
                    showPlantID: json.showPlantID,
                    isFree: json.isFree ?? false
                )
                modelContext.insert(term)
            }
        } catch {
            print("[DataLoader] Failed to load Botany.json: \(error)")
        }
    }

    // MARK: - Default User Settings

    private func createDefaultUserSettings(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<UserSettings>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        if existing.isEmpty {
            let settings = UserSettings()
            modelContext.insert(settings)
            print("[DataLoader] Created default UserSettings")
        }
    }

    // MARK: - Seed Achievements

    private func seedAchievements(modelContext: ModelContext) {
        let achievements: [(String, String, String)] = [
            ("First Observation", "Record your first plant observation", "observe"),
            ("Keen Eye", "Observe 10 different species", "observe"),
            ("Botanist", "Observe 50 different species", "observe"),
            ("Master Botanist", "Observe all 179 species", "observe"),
            ("Family Ties", "Explore 10 plant families", "learn"),
            ("Taxonomist", "Explore all 183 families", "learn"),
            ("Vocabulary", "Learn 50 botanical terms", "learn"),
            ("Lexicon", "Learn all 464 terms", "learn"),
            ("Streak Starter", "Maintain a 3-day streak", "streak"),
            ("Week Warrior", "Maintain a 7-day streak", "streak"),
            ("Month Master", "Maintain a 30-day streak", "streak"),
            ("Sharp Shooter", "Get a 90%+ match with Capture", "capture"),
            ("Trait Tracker", "Verify 10 traits in Both mode", "capture"),
            ("Collector", "Create your first collection", "journal"),
            ("Curator", "Add 25 observations to journal", "journal"),
        ]

        for (name, description, category) in achievements {
            let achievement = Achievement(
                name: name,
                achievementDescription: description,
                category: category
            )
            modelContext.insert(achievement)
        }
        print("[DataLoader] Seeded \(achievements.count) achievements")
    }
}
