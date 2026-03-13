import Foundation
import SwiftData
import UIKit

@MainActor
final class DataLoader {

    static let shared = DataLoader()
    private init() {}

    private let dataLoadedKey = "com.radicle.radiclebotany.dataLoaded"
    private let dataVersionKey = "com.radicle.radiclebotany.dataVersion"
    private let currentDataVersion = 5

    // MARK: - Main Load

    func loadAllDataIfNeeded(modelContext: ModelContext) {
        print("[DataLoader] ========== STARTING DATA LOAD ==========")
        let startTime = Date()

        let storedVersion = UserDefaults.standard.integer(forKey: dataVersionKey)
        let needsDataUpgrade = storedVersion < currentDataVersion

        // Check each data type independently to avoid duplicating already-loaded data
        let plantCount = (try? modelContext.fetchCount(FetchDescriptor<Plant>())) ?? 0
        let familyCount = (try? modelContext.fetchCount(FetchDescriptor<Family>())) ?? 0
        let termCount = (try? modelContext.fetchCount(FetchDescriptor<BotanyTerm>())) ?? 0
        print("[DataLoader] Current counts — Plants: \(plantCount), Families: \(familyCount), Terms: \(termCount)")
        print("[DataLoader] Data version: stored=\(storedVersion), current=\(currentDataVersion), upgrade=\(needsDataUpgrade)")

        var didLoadAnything = false

        // If data version changed, reload plants from updated JSON
        if needsDataUpgrade && plantCount > 0 {
            print("[DataLoader] Data version upgrade detected — reloading plants from updated JSON...")
            reloadPlants(modelContext: modelContext)
            didLoadAnything = true
        } else if plantCount == 0 {
            loadPlants(modelContext: modelContext)
            didLoadAnything = true
        }

        if familyCount == 0 {
            loadFamilies(modelContext: modelContext)
            didLoadAnything = true
        }

        if termCount == 0 {
            loadBotanyTerms(modelContext: modelContext)
            didLoadAnything = true
        }

        createDefaultUserSettings(modelContext: modelContext)
        seedAchievements(modelContext: modelContext)
        migrateBloomData(modelContext: modelContext)

        if didLoadAnything {
            do {
                try modelContext.save()
                UserDefaults.standard.set(true, forKey: dataLoadedKey)
                UserDefaults.standard.set(currentDataVersion, forKey: dataVersionKey)
                let elapsed = Date().timeIntervalSince(startTime)
                let finalPlants = (try? modelContext.fetchCount(FetchDescriptor<Plant>())) ?? 0
                let finalFamilies = (try? modelContext.fetchCount(FetchDescriptor<Family>())) ?? 0
                let finalTerms = (try? modelContext.fetchCount(FetchDescriptor<BotanyTerm>())) ?? 0
                print("[DataLoader] ✅ Data loaded and saved in \(String(format: "%.2f", elapsed))s")
                print("[DataLoader]    Plants: \(finalPlants), Families: \(finalFamilies), Terms: \(finalTerms)")
            } catch {
                print("[DataLoader] ❌ Failed to save data: \(error)")
                print("[DataLoader] ❌ Error details: \(String(describing: error))")
            }
        } else {
            print("[DataLoader] ✅ All data already loaded. Skipping.")
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
                    familyLatin: json.plantFamily ?? "",
                    plantDescription: json.plantDescription ?? "",
                    kingdom: json.plantKingdom ?? "Plantae",
                    taxonomicClass: json.plantClass ?? "",
                    order: json.plantOrder ?? "",
                    genus: json.plantGenus ?? "",
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

                // Bloom/Fruit timing
                plant.bloomMonths = json.bloomMonths
                plant.fruitMonths = json.fruitMonths

                // Pre-baked image URLs (from scripts/export_image_urls.py)
                plant.imageURL = json.imageURL
                plant.flowerImageURL = json.flowerImageURL
                plant.leafImageURL = json.leafImageURL
                plant.fruitImageURL = json.fruitImageURL
                plant.barkImageURL = json.barkImageURL
                plant.stemImageURL = json.stemImageURL
                plant.habitImageURL = json.habitImageURL
                plant.gbifId = json.gbifId

                modelContext.insert(plant)
            }
        } catch {
            print("[DataLoader] Failed to load Plants.json: \(error)")
        }
    }

    // MARK: - Reload Plants (Version Upgrade)

    /// Merges species from Plants.json into the existing SwiftData store.
    /// - Adds new species not already present (matched by scientificName).
    /// - Updates pre-baked image URLs on existing plants that are missing them.
    ///   User-fetched image URLs and cached data are preserved.
    private func reloadPlants(modelContext: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Plants", withExtension: "json") else {
            print("[DataLoader] Plants.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PlantJSON].self, from: data)
            print("[DataLoader] Plants.json contains \(decoded.count) species")

            // Build lookup of existing plants by name
            let descriptor = FetchDescriptor<Plant>()
            let existingPlants = (try? modelContext.fetch(descriptor)) ?? []
            let existingByName = Dictionary(uniqueKeysWithValues: existingPlants.map { ($0.scientificName, $0) })
            print("[DataLoader] Existing plants in store: \(existingByName.count)")

            // Merge: update image URLs on existing plants + insert new species
            var addedCount = 0
            var updatedCount = 0
            let freeThreshold = 30
            let totalExisting = existingByName.count

            for (index, json) in decoded.enumerated() {
                if let existing = existingByName[json.plantNameLatin] {
                    // Update pre-baked image URLs only if the existing plant has none
                    // This fills in URLs from the enrichment script without overwriting
                    // any images the user's device may have already fetched via API
                    var didUpdate = false
                    if existing.imageURL == nil, let url = json.imageURL { existing.imageURL = url; didUpdate = true }
                    if existing.flowerImageURL == nil, let url = json.flowerImageURL { existing.flowerImageURL = url; didUpdate = true }
                    if existing.leafImageURL == nil, let url = json.leafImageURL { existing.leafImageURL = url; didUpdate = true }
                    if existing.fruitImageURL == nil, let url = json.fruitImageURL { existing.fruitImageURL = url; didUpdate = true }
                    if existing.barkImageURL == nil, let url = json.barkImageURL { existing.barkImageURL = url; didUpdate = true }
                    if existing.stemImageURL == nil, let url = json.stemImageURL { existing.stemImageURL = url; didUpdate = true }
                    if existing.habitImageURL == nil, let url = json.habitImageURL { existing.habitImageURL = url; didUpdate = true }
                    if existing.gbifId == nil, let id = json.gbifId { existing.gbifId = id; didUpdate = true }
                    if didUpdate { updatedCount += 1 }
                } else {
                    let plant = Plant(
                        scientificName: json.plantNameLatin,
                        commonName: json.plantNameCommon,
                        familyLatin: json.plantFamily ?? "",
                        plantDescription: json.plantDescription ?? "",
                        kingdom: json.plantKingdom ?? "Plantae",
                        taxonomicClass: json.plantClass ?? "",
                        order: json.plantOrder ?? "",
                        genus: json.plantGenus ?? "",
                        isFree: (totalExisting + addedCount) < freeThreshold,
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

                    // Bloom/Fruit timing
                    plant.bloomMonths = json.bloomMonths
                    plant.fruitMonths = json.fruitMonths

                    // Pre-baked image URLs
                    plant.imageURL = json.imageURL
                    plant.flowerImageURL = json.flowerImageURL
                    plant.leafImageURL = json.leafImageURL
                    plant.fruitImageURL = json.fruitImageURL
                    plant.barkImageURL = json.barkImageURL
                    plant.stemImageURL = json.stemImageURL
                    plant.habitImageURL = json.habitImageURL
                    plant.gbifId = json.gbifId

                    modelContext.insert(plant)
                    addedCount += 1
                }
            }

            print("[DataLoader] Added \(addedCount) new species, updated \(updatedCount) existing with image URLs")
        } catch {
            print("[DataLoader] Failed to reload Plants.json: \(error)")
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

            for (index, json) in decoded.enumerated() {
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

                // Access
                family.isFree = index < 10

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
                    colorImageURL: json.colorImageURL,
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
        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<Achievement>())) ?? 0
        guard existingCount == 0 else {
            // For existing users, run flashcard achievement migration
            seedFlashcardAchievements(modelContext: modelContext)
            updateExistingAchievementTypes(modelContext: modelContext)
            return
        }

        // Fresh install: seed all 27 achievements with types and thresholds
        let achievements: [(String, String, String, String?, Int?)] = [
            // Original 15 (with types where applicable)
            ("First Observation", "Record your first plant observation", "observe", nil, nil),
            ("Keen Eye", "Observe 10 different species", "observe", nil, nil),
            ("Botanist", "Observe 50 different species", "observe", nil, nil),
            ("Master Botanist", "Observe all species", "observe", nil, nil),
            ("Family Ties", "Explore 10 plant families", "learn", "flashcard_families_mastered", 10),
            ("Taxonomist", "Explore all 183 families", "learn", nil, nil),
            ("Vocabulary", "Learn 50 botanical terms", "learn", "flashcard_terms_mastered", 50),
            ("Lexicon", "Learn all 461 terms", "learn", nil, nil),
            ("Streak Starter", "Maintain a 3-day streak", "streak", "flashcard_study_streak", 3),
            ("Week Warrior", "Maintain a 7-day streak", "streak", "flashcard_study_streak", 7),
            ("Month Master", "Maintain a 30-day streak", "streak", "flashcard_study_streak", 30),
            ("Sharp Shooter", "Get a 90%+ match with Capture", "capture", nil, nil),
            ("Trait Tracker", "Verify 10 traits in Both mode", "capture", nil, nil),
            ("Collector", "Create your first collection", "journal", nil, nil),
            ("Curator", "Add 25 observations to journal", "journal", nil, nil),
            // New 12 flashcard achievements
            ("Quick Study", "Review 50 flashcards", "flashcard", "flashcard_cards_reviewed", 50),
            ("Scholar", "Review 500 flashcards", "flashcard", "flashcard_cards_reviewed", 500),
            ("Flashcard Streak", "Study 3 days in a row", "flashcard", "flashcard_study_streak", 3),
            ("Study Habit", "Study 7 days in a row", "flashcard", "flashcard_study_streak", 7),
            ("Dedicated Learner", "Study 30 days in a row", "flashcard", "flashcard_study_streak", 30),
            ("XP Starter", "Earn 500 XP", "flashcard", "flashcard_xp_milestone", 500),
            ("XP Pro", "Earn 2,500 XP", "flashcard", "flashcard_xp_milestone", 2500),
            ("XP Legend", "Earn 10,000 XP", "flashcard", "flashcard_xp_milestone", 10000),
            ("Perfect Session", "Complete a deck with all cards mastered", "flashcard", "flashcard_session_perfect", 1),
            ("Term Apprentice", "Master 25 botanical terms", "flashcard", "flashcard_terms_mastered", 25),
            ("Species Scholar", "Master 50 species", "flashcard", "flashcard_plants_mastered", 50),
            ("Family Expert", "Master 50 families", "flashcard", "flashcard_families_mastered", 50),
        ]

        for (name, description, category, type, threshold) in achievements {
            let achievement = Achievement(
                name: name,
                achievementDescription: description,
                category: category,
                achievementType: type,
                threshold: threshold
            )
            modelContext.insert(achievement)
        }
        print("[DataLoader] Seeded \(achievements.count) achievements (including flashcard gamification)")
    }

    // MARK: - Flashcard Achievement Migration (Existing Users)

    private let flashcardAchievementKey = "com.radicle.radiclebotany.flashcardAchievementsSeeded"

    /// Seeds 12 new flashcard achievements for existing users who already have the original 15.
    private func seedFlashcardAchievements(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flashcardAchievementKey) else { return }

        let newAchievements: [(String, String, String, String, Int)] = [
            ("Quick Study", "Review 50 flashcards", "flashcard", "flashcard_cards_reviewed", 50),
            ("Scholar", "Review 500 flashcards", "flashcard", "flashcard_cards_reviewed", 500),
            ("Flashcard Streak", "Study 3 days in a row", "flashcard", "flashcard_study_streak", 3),
            ("Study Habit", "Study 7 days in a row", "flashcard", "flashcard_study_streak", 7),
            ("Dedicated Learner", "Study 30 days in a row", "flashcard", "flashcard_study_streak", 30),
            ("XP Starter", "Earn 500 XP", "flashcard", "flashcard_xp_milestone", 500),
            ("XP Pro", "Earn 2,500 XP", "flashcard", "flashcard_xp_milestone", 2500),
            ("XP Legend", "Earn 10,000 XP", "flashcard", "flashcard_xp_milestone", 10000),
            ("Perfect Session", "Complete a deck with all cards mastered", "flashcard", "flashcard_session_perfect", 1),
            ("Term Apprentice", "Master 25 botanical terms", "flashcard", "flashcard_terms_mastered", 25),
            ("Species Scholar", "Master 50 species", "flashcard", "flashcard_plants_mastered", 50),
            ("Family Expert", "Master 50 families", "flashcard", "flashcard_families_mastered", 50),
        ]

        for (name, description, category, type, threshold) in newAchievements {
            let achievement = Achievement(
                name: name,
                achievementDescription: description,
                category: category,
                achievementType: type,
                threshold: threshold
            )
            modelContext.insert(achievement)
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: flashcardAchievementKey)
        print("[DataLoader] Seeded \(newAchievements.count) new flashcard achievements for existing user")
    }

    // MARK: - Update Existing Achievement Types

    private let achievementTypesUpdatedKey = "com.radicle.radiclebotany.achievementTypesUpdated"

    /// One-time migration: adds achievementType/threshold to existing achievements
    /// so AchievementService can check them programmatically.
    private func updateExistingAchievementTypes(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: achievementTypesUpdatedKey) else { return }

        let descriptor = FetchDescriptor<Achievement>()
        guard let allAchievements = try? modelContext.fetch(descriptor) else { return }

        let typeMap: [String: (String, Int)] = [
            "Family Ties": ("flashcard_families_mastered", 10),
            "Vocabulary": ("flashcard_terms_mastered", 50),
            "Streak Starter": ("flashcard_study_streak", 3),
            "Week Warrior": ("flashcard_study_streak", 7),
            "Month Master": ("flashcard_study_streak", 30),
        ]

        var updated = 0
        for achievement in allAchievements {
            if let mapping = typeMap[achievement.name], achievement.achievementType == nil {
                achievement.achievementType = mapping.0
                achievement.threshold = mapping.1
                updated += 1
            }
        }

        if updated > 0 {
            try? modelContext.save()
            print("[DataLoader] Updated \(updated) existing achievements with types")
        }

        UserDefaults.standard.set(true, forKey: achievementTypesUpdatedKey)
    }

    // MARK: - Bloom Data Migration

    private let bloomMigrationKey = "com.radicle.radiclebotany.bloomDataMigrated"

    /// One-time migration: populates bloomMonths/fruitMonths from Plants.json
    /// for existing users who already had plants loaded before these fields existed.
    func migrateBloomData(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: bloomMigrationKey) else { return }

        guard let url = Bundle.main.url(forResource: "Plants", withExtension: "json") else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PlantJSON].self, from: data)

            let descriptor = FetchDescriptor<Plant>()
            guard let allPlants = try? modelContext.fetch(descriptor) else { return }

            let plantMap = Dictionary(uniqueKeysWithValues: allPlants.map { ($0.scientificName, $0) })

            var updated = 0
            for json in decoded {
                guard let plant = plantMap[json.plantNameLatin] else { continue }
                if plant.bloomMonths == nil, let bloom = json.bloomMonths, !bloom.isEmpty {
                    plant.bloomMonths = bloom
                    updated += 1
                }
                if plant.fruitMonths == nil, let fruit = json.fruitMonths, !fruit.isEmpty {
                    plant.fruitMonths = fruit
                }
            }

            if updated > 0 {
                try? modelContext.save()
                print("[DataLoader] 🌸 Migrated bloom data for \(updated) plants")
            }
        } catch {
            print("[DataLoader] Failed to migrate bloom data: \(error)")
        }

        UserDefaults.standard.set(true, forKey: bloomMigrationKey)
    }

    // MARK: - Image Source Migration

    private let inatMigrationKey = "com.radicle.radiclebotany.inatImagesMigrated"

    /// One-time migration: clears all existing plant image URLs so they get re-fetched
    /// from iNaturalist (replacing any previous PlantNet or Wikipedia images).
    private func migrateToINaturalistImages(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: inatMigrationKey) else { return }

        let descriptor = FetchDescriptor<Plant>()
        guard let allPlants = try? modelContext.fetch(descriptor) else { return }

        var cleared = 0
        for plant in allPlants {
            let hadImage = plant.imageURL != nil || plant.leafImageURL != nil || plant.flowerImageURL != nil
            if hadImage {
                plant.imageURL = nil
                for organ in PlantOrgan.imageOrgans {
                    plant.setImageURL(nil, for: organ)
                }
                cleared += 1
            }
        }

        if cleared > 0 {
            try? modelContext.save()
            print("[DataLoader] 🔄 Cleared images from \(cleared) plants for iNaturalist migration")
        }

        UserDefaults.standard.set(true, forKey: inatMigrationKey)
    }

    // MARK: - Wikipedia Image Migration

    private let wikiMigrationKey = "com.radicle.radiclebotany.wikiImagesCleared"

    /// One-time migration: clears any Wikipedia-sourced image URLs so they get
    /// re-fetched through the 3-tier pipeline (iNaturalist → GBIF → Wikipedia).
    private func clearWikipediaImages(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: wikiMigrationKey) else { return }

        let descriptor = FetchDescriptor<Plant>()
        guard let allPlants = try? modelContext.fetch(descriptor) else { return }

        var cleared = 0
        for plant in allPlants {
            var didClear = false

            // Check general image URL
            if let url = plant.imageURL,
               url.contains("wikipedia.org") || url.contains("wikimedia.org") {
                plant.imageURL = nil
                didClear = true
            }

            // Check all organ image URLs
            for organ in PlantOrgan.imageOrgans {
                if let url = plant.imageURL(for: organ),
                   url.contains("wikipedia.org") || url.contains("wikimedia.org") {
                    plant.setImageURL(nil, for: organ)
                    didClear = true
                }
            }

            if didClear { cleared += 1 }
        }

        if cleared > 0 {
            try? modelContext.save()
            print("[DataLoader] 🔄 Cleared Wikipedia images from \(cleared) plants for re-fetch")
        }

        UserDefaults.standard.set(true, forKey: wikiMigrationKey)
    }

    // MARK: - Plant Images

    /// Fetches image URLs for plants that don't yet have images.
    /// Uses a 3-tier strategy: iNaturalist → GBIF → Wikipedia.
    /// Call this AFTER enrichment (so GBIF IDs are available for Tier 2).
    /// Uses batched concurrency (3 at a time) with 500ms pauses to respect API rate limits.
    func loadPlantImages(modelContext: ModelContext) async {
        // One-time migrations
        migrateToINaturalistImages(modelContext: modelContext)
        clearWikipediaImages(modelContext: modelContext)

        // Fetch plants that have no image URLs at all (skips pre-baked plants from JSON)
        let predicate = #Predicate<Plant> {
            $0.imageURL == nil
        }
        let descriptor = FetchDescriptor<Plant>(predicate: predicate)

        guard let plantsNeedingImages = try? modelContext.fetch(descriptor),
              !plantsNeedingImages.isEmpty else {
            print("[DataLoader] All plants already have images or no plants found.")
            return
        }

        print("[DataLoader] Fetching images for \(plantsNeedingImages.count) plants (3-tier: iNaturalist → GBIF → Wikipedia)...")
        let startTime = Date()
        var successCount = 0
        var organImageCount = 0
        var failCount = 0
        var tierCounts: [String: Int] = [:]

        // Process in batches of 5 concurrent requests
        // iNaturalist rate limit is ~100 req/min; 2 requests per plant × 5 batch = 10 requests
        let batchSize = 5
        var processedCount = 0
        for batchStart in stride(from: 0, to: plantsNeedingImages.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, plantsNeedingImages.count)
            let batch = Array(plantsNeedingImages[batchStart..<batchEnd])

            await withTaskGroup(of: (Int, PlantImageResult).self) { group in
                for (index, plant) in batch.enumerated() {
                    let gbifId = plant.gbifId
                    group.addTask {
                        let result = await PlantImageService.shared.fetchAllImages(
                            for: plant.scientificName,
                            gbifId: gbifId
                        )
                        return (index, result)
                    }
                }

                for await (index, result) in group {
                    let plant = batch[index]

                    if result.hasAnyImage {
                        if let newGeneral = result.generalImageURL {
                            plant.imageURL = newGeneral
                        }
                        for (organ, url) in result.organImages {
                            plant.setImageURL(url, for: organ)
                            organImageCount += 1
                        }
                        successCount += 1
                        if !result.source.isEmpty {
                            tierCounts[result.source, default: 0] += 1
                        }
                    } else {
                        failCount += 1
                    }
                }
            }

            processedCount += batch.count

            // Save every 25 plants instead of every batch to reduce context churn
            if processedCount % 25 < batchSize {
                try? modelContext.save()
            }

            // Pause between batches to respect iNaturalist rate limits
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        // Final save for any remaining
        try? modelContext.save()

        let elapsed = Date().timeIntervalSince(startTime)
        let tierSummary = tierCounts.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        print("[DataLoader] Image fetch complete in \(String(format: "%.1f", elapsed))s")
        print("[DataLoader]   Species with images: \(successCount), Organ images: \(organImageCount), Failed: \(failCount)")
        print("[DataLoader]   Sources: \(tierSummary.isEmpty ? "none" : tierSummary)")
    }

    // MARK: - Species Enrichment (IUCN + Common Names)

    /// Enriches plants with IUCN conservation status and alternative common names from PlantNet.
    /// Runs in batches with rate limiting, same pattern as loadPlantImages.
    func loadSpeciesEnrichment(modelContext: ModelContext) async {
        // Only enrich plants that haven't been processed yet
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { $0.atRiskStatus == nil && $0.alternativeCommonNames == nil }
        )

        guard let plantsToEnrich = try? modelContext.fetch(descriptor),
              !plantsToEnrich.isEmpty else {
            print("[DataLoader] All plants already enriched or no plants found.")
            return
        }

        print("[DataLoader] Enriching \(plantsToEnrich.count) plants with IUCN status + common names...")
        let startTime = Date()
        var iucnCount = 0
        var altNameCount = 0

        let batchSize = 5
        var enrichedCount = 0
        for batchStart in stride(from: 0, to: plantsToEnrich.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, plantsToEnrich.count)
            let batch = Array(plantsToEnrich[batchStart..<batchEnd])

            await withTaskGroup(of: (Int, SpeciesInfo?).self) { group in
                for (index, plant) in batch.enumerated() {
                    group.addTask {
                        let info = await PlantNetSpeciesService.shared.fetchSpeciesInfo(
                            scientificName: plant.scientificName
                        )
                        return (index, info)
                    }
                }

                for await (index, info) in group {
                    let plant = batch[index]

                    // IUCN conservation status
                    if let categoryStr = info?.iucnCategory,
                       let category = IUCNCategory(rawValue: categoryStr) {
                        plant.isAtRisk = category.isAtRisk
                        plant.atRiskStatus = category.isAtRisk ? category.displayString : "Least Concern"
                        if category.isAtRisk {
                            iucnCount += 1
                        }
                    } else {
                        plant.atRiskStatus = plant.atRiskStatus ?? "Not Evaluated"
                    }

                    // GBIF species ID (used for Tier 2 image fetching)
                    if let gbifSpeciesId = info?.gbif?.id {
                        plant.gbifId = gbifSpeciesId
                    }

                    // Alternative common names
                    if let allNames = info?.commonNames, allNames.count > 1 {
                        let alternatives = Array(allNames.dropFirst()).prefix(5)
                        plant.alternativeCommonNames = alternatives.joined(separator: ", ")
                        altNameCount += 1
                    } else {
                        plant.alternativeCommonNames = plant.alternativeCommonNames ?? ""
                    }
                }
            }

            enrichedCount += batch.count

            // Save every 50 plants to reduce context churn
            if enrichedCount % 50 < batchSize {
                try? modelContext.save()
            }

            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        }
        // Final save for any remaining
        try? modelContext.save()

        let elapsed = Date().timeIntervalSince(startTime)
        print("[DataLoader] Enrichment complete in \(String(format: "%.1f", elapsed))s")
        print("[DataLoader]   At-risk species: \(iucnCount), Species with alt names: \(altNameCount)")
    }

    // MARK: - Persistent Image Caching

    /// Downloads and persistently stores the best available image for every plant.
    /// This guarantees every plant ALWAYS has an image, even offline or when APIs are unavailable.
    /// Runs after loadPlantImages() so URLs are already populated.
    /// Uses batched concurrency (5 at a time) with incremental saves.
    func cacheAllPlantImages(modelContext: ModelContext) async {
        // Only cache plants that have a URL but no cached data yet
        let descriptor = FetchDescriptor<Plant>(
            predicate: #Predicate<Plant> { $0.cachedImageData == nil }
        )

        guard let plantsNeedingCache = try? modelContext.fetch(descriptor),
              !plantsNeedingCache.isEmpty else {
            print("[DataLoader] All plants already have cached images or no plants found.")
            return
        }

        // Filter to only plants that have at least one image URL to download
        let plantsWithURLs = plantsNeedingCache.filter { $0.bestImageURL != nil }

        guard !plantsWithURLs.isEmpty else {
            print("[DataLoader] No plants with image URLs to cache.")
            return
        }

        print("[DataLoader] Caching images for \(plantsWithURLs.count) plants...")
        let startTime = Date()
        var successCount = 0
        var failCount = 0

        // Process in batches of 4 concurrent downloads — gentle on CPU/battery.
        // Larger batches (10-20) cause UI freezing from concurrent JPEG decode + SwiftData writes.
        let batchSize = 4
        for batchStart in stride(from: 0, to: plantsWithURLs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, plantsWithURLs.count)
            let batch = Array(plantsWithURLs[batchStart..<batchEnd])

            await withTaskGroup(of: (Int, Data?).self) { group in
                for (index, plant) in batch.enumerated() {
                    guard let urlString = plant.bestImageURL,
                          let url = URL(string: urlString) else {
                        continue
                    }

                    group.addTask {
                        do {
                            let (data, response) = try await URLSession.shared.data(from: url)
                            guard let httpResponse = response as? HTTPURLResponse,
                                  httpResponse.statusCode == 200,
                                  !data.isEmpty else {
                                return (index, nil)
                            }

                            guard let uiImage = UIImage(data: data),
                                  let compressed = uiImage.jpegData(compressionQuality: 0.85) else {
                                return (index, nil)
                            }

                            return (index, compressed)
                        } catch {
                            return (index, nil)
                        }
                    }
                }

                for await (index, imageData) in group {
                    guard index < batch.count else { continue }
                    let plant = batch[index]

                    if let imageData {
                        plant.cachedImageData = imageData
                        successCount += 1
                    } else {
                        failCount += 1
                    }
                }
            }

            // Save after each batch to persist progress incrementally
            try? modelContext.save()

            // 500ms yield between batches — this runs at .background priority
            // so it should barely impact UI, but the yield ensures it doesn't
            // accumulate CPU pressure over hundreds of batches.
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("[DataLoader] Image caching complete in \(String(format: "%.1f", elapsed))s — Cached: \(successCount), Failed: \(failCount)")
    }

    // MARK: - Bundled Plant Images

    private let plantImagesLoadedKey = "com.radicle.radiclebotany.bundledPlantImagesLoaded.v2"

    /// Loads pre-bundled 240px plant images from the app bundle into SwiftData.
    /// Runs once on first launch — every plant gets an instant image with zero network.
    /// Images are ~15-30KB each, stored via @externalStorage for efficient access.
    /// PlantDetailView upgrades these to full-resolution (~1024px) when viewed.
    nonisolated func loadBundledPlantImages(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: plantImagesLoadedKey) else {
            print("[DataLoader] Bundled plant images already loaded, skipping.")
            return
        }

        let startTime = Date()

        // Try PlantImages first (240px), fall back to PlantThumbnails (75×75) for legacy
        let imageDir: URL?
        if let dir = Bundle.main.url(forResource: "PlantImages", withExtension: nil) {
            imageDir = dir
        } else if let dir = Bundle.main.url(forResource: "PlantThumbnails", withExtension: nil) {
            imageDir = dir
            print("[DataLoader] ⚠️ PlantImages not found, falling back to PlantThumbnails")
        } else {
            print("[DataLoader] ⚠️ No bundled plant images folder found in bundle")
            return
        }

        guard let dir = imageDir else { return }

        // Fetch all plants
        let descriptor = FetchDescriptor<Plant>()
        guard let allPlants = try? modelContext.fetch(descriptor) else {
            print("[DataLoader] ⚠️ Failed to fetch plants for image loading")
            return
        }

        var loadedCount = 0
        var upgradedCount = 0
        var missedCount = 0

        for plant in allPlants {
            // Skip if already has a full-size cached image (>50KB = network-downloaded)
            if let existingData = plant.cachedImageData, existingData.count > 50_000 {
                continue
            }

            // Match scientific name to filename: "Abies amabilis" → "Abies_amabilis.jpg"
            let filename = plant.scientificName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "\"", with: "") + ".jpg"

            let fileURL = dir.appendingPathComponent(filename)

            if let data = try? Data(contentsOf: fileURL) {
                let wasUpgrade = plant.cachedImageData != nil
                plant.cachedImageData = data
                if wasUpgrade {
                    upgradedCount += 1
                } else {
                    loadedCount += 1
                }
            } else {
                missedCount += 1
            }
        }

        // Save all at once
        try? modelContext.save()

        UserDefaults.standard.set(true, forKey: plantImagesLoadedKey)
        let elapsed = Date().timeIntervalSince(startTime)
        print("[DataLoader] ✅ Bundled plant images loaded in \(String(format: "%.2f", elapsed))s — New: \(loadedCount), Upgraded: \(upgradedCount), Missing: \(missedCount)")
    }

    /// Downloads and caches a large-resolution image for a single plant (used on detail view).
    /// Uses largeImageURL (~1024px) for Retina-sharp offline display.
    func cacheSinglePlantImage(plant: Plant, modelContext: ModelContext) async {
        guard let urlString = plant.largeImageURL,
              let url = URL(string: urlString) else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let uiImage = UIImage(data: data),
                  let compressed = uiImage.jpegData(compressionQuality: 0.85) else { return }

            plant.cachedImageData = compressed
            try? modelContext.save()
            print("[DataLoader] 💾 Cached image for \(plant.scientificName)")
        } catch {
            print("[DataLoader] ❌ Failed to cache image for \(plant.scientificName): \(error.localizedDescription)")
        }
    }

    /// Re-fetches images for a specific plant, replacing any existing URLs.
    /// Called from admin screen when user wants to refresh images.
    /// Uses the full 3-tier cascade: iNaturalist → GBIF → Wikipedia.
    func refreshPlantImages(plant: Plant, modelContext: ModelContext) async {
        print("[DataLoader] Refreshing images for \(plant.scientificName) (gbifId: \(plant.gbifId?.description ?? "none"))...")

        let result = await PlantImageService.shared.fetchAllImages(
            for: plant.scientificName,
            gbifId: plant.gbifId
        )

        if result.hasAnyImage {
            plant.imageURL = result.generalImageURL

            for organ in PlantOrgan.imageOrgans {
                plant.setImageURL(result.organImages[organ], for: organ)
            }

            // Also re-cache the persistent image data
            plant.cachedImageData = nil // Clear old cache
            try? modelContext.save()

            // Download and cache the new best image
            await cacheSinglePlantImage(plant: plant, modelContext: modelContext)

            print("[DataLoader] ✅ Refreshed from \(result.source): \(result.organImages.count) organ images")
        } else {
            print("[DataLoader] ⚠️ No images found for \(plant.scientificName)")
        }
    }
}
