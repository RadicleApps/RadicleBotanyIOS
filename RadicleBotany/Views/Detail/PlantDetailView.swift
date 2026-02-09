import SwiftUI
import SwiftData

struct PlantDetailView: View {
    let plant: Plant

    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query private var allPlants: [Plant]
    @Query private var allFamilies: [Family]
    @Query private var allObservations: [PlantObservation]

    @State private var showPaywall = false

    // MARK: - Filtered Data

    private var familyMatch: Family? {
        allFamilies.first { $0.familyLatin == plant.familyLatin }
    }

    private var relatedSpecies: [Plant] {
        allPlants.filter { $0.familyLatin == plant.familyLatin && $0.scientificName != plant.scientificName }
    }

    private var observedScientificNames: Set<String> {
        Set(allObservations.compactMap { $0.plantScientificName })
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                headerSection
                descriptionSection
                traitsSection
                relatedSpeciesSection
                saveToJournalSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle(plant.commonName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Hero Image

    private var heroSection: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.surfaceElevated)
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.greenSecondary.opacity(0.4))
                    Text("Plant Image")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plant.scientificName)
                .font(AppFont.title())
                .italic()
                .foregroundStyle(Color.textPrimary)

            Text(plant.commonName)
                .font(AppFont.bodyLarge())
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: 8) {
                if let family = familyMatch {
                    NavigationLink(value: family) {
                        CategoryPill(text: plant.familyLatin, color: .orangePrimary)
                    }
                } else {
                    CategoryPill(text: plant.familyLatin, color: .orangePrimary)
                }

                if plant.isAtRisk {
                    AtRiskBadge(status: plant.atRiskStatus ?? "At-Risk")
                }

                CategoryPill(text: "Full Profile", color: .greenSecondary)
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)

            Text(markdownToAttributed(plant.plantDescription))
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(4)
        }
        .cardStyle()
    }

    // MARK: - Traits

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Traits")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                traitDisclosureGroup(title: "Leaf Traits", icon: "leaf.fill", traits: leafTraits)
                traitDisclosureGroup(title: "Stem Traits", icon: "arrow.up.and.line.horizontal.and.arrow.down", traits: stemTraits)
                traitDisclosureGroup(title: "Flower Traits", icon: "camera.macro", traits: flowerTraits)
                traitDisclosureGroup(title: "Fruit Traits", icon: "apple.logo", traits: fruitTraits)
                traitDisclosureGroup(title: "Root Traits", icon: "arrow.down.to.line", traits: rootTraits)
                traitDisclosureGroup(title: "Habitat", icon: "mountain.2.fill", traits: habitatTraits)
            }
            .cardStyle(padding: 0)
        }
    }

    private var leafTraits: [(String, String)] {
        [
            ("Type", plant.leafType),
            ("Attachment", plant.leafAttachment),
            ("Arrangement", plant.leafArrangement),
            ("Shape", plant.leafShape),
            ("Margin", plant.leafMargin),
            ("Apex", plant.leafApex),
            ("Base", plant.leafBase),
            ("Venation", plant.leafVenation),
            ("Texture", plant.leafTexture),
            ("Stipules", plant.leafStipules)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var stemTraits: [(String, String)] {
        [
            ("Habit", plant.stemHabit),
            ("Structure", plant.stemStructure),
            ("Branching", plant.stemBranching)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var flowerTraits: [(String, String)] {
        [
            ("Inflorescence", plant.flowerInflorescence),
            ("Symmetry", plant.flowerSymmetry),
            ("Petal Count", plant.flowerPetalCount),
            ("Petal Fusion", plant.flowerPetalFusion),
            ("Sepal Presence", plant.flowerSepalPresence),
            ("Sepal Fusion", plant.flowerSepalFusion),
            ("Color", plant.flowerColor),
            ("Position", plant.flowerPosition),
            ("Ovary Position", plant.flowerOvaryPosition),
            ("Sexuality", plant.flowerSexuality),
            ("Floral Part", plant.flowerFloralPart)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var fruitTraits: [(String, String)] {
        [
            ("Type", plant.fruitType),
            ("Seed Trait", plant.fruitSeedTrait)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var rootTraits: [(String, String)] {
        [
            ("Type", plant.rootType)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var habitatTraits: [(String, String)] {
        [
            ("Habitat", plant.habitat),
            ("Soil", plant.soil),
            ("Growth Habit", plant.growthHabit)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    @ViewBuilder
    private func traitDisclosureGroup(title: String, icon: String, traits: [(String, String)]) -> some View {
        if !traits.isEmpty {
            DisclosureGroup {
                VStack(spacing: 0) {
                    ForEach(Array(traits.enumerated()), id: \.offset) { index, trait in
                        traitRow(name: trait.0, value: trait.1)

                        if index < traits.count - 1 {
                            Divider()
                                .background(Color.borderSubtle)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.greenSecondary)
                        .frame(width: 24)

                    Text(title)
                        .font(AppFont.sectionHeader())
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Text("\(traits.count)")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            }
            .tint(Color.textSecondary)
            .padding(16)
        }
    }

    private func traitRow(name: String, value: String) -> some View {
        HStack {
            Text(name)
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(value)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Related Species

    @ViewBuilder
    private var relatedSpeciesSection: some View {
        if !relatedSpecies.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Related Species")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(relatedSpecies, id: \.scientificName) { relatedPlant in
                            NavigationLink(value: relatedPlant) {
                                relatedPlantCard(relatedPlant)
                            }
                        }
                    }
                }
            }
        }
    }

    private func relatedPlantCard(_ relatedPlant: Plant) -> some View {
        let hasObservation = observedScientificNames.contains(relatedPlant.scientificName)

        return VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.surfaceElevated)
                .frame(width: 130, height: 90)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundStyle(Color.greenSecondary.opacity(0.3))
                )

            Text(relatedPlant.commonName)
                .font(AppFont.caption())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(relatedPlant.scientificName)
                .font(AppFont.caption(10))
                .foregroundStyle(Color.textMuted)
                .italic()
                .lineLimit(1)
        }
        .frame(width: 130)
        .padding(8)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    hasObservation ? Color.greenSecondary : Color.borderSubtle,
                    lineWidth: hasObservation ? 1.5 : 0.5
                )
        )
        .shadow(
            color: hasObservation ? Color.greenSecondary.opacity(0.25) : .clear,
            radius: hasObservation ? 6 : 0
        )
    }

    // MARK: - Save to Journal

    private var saveToJournalSection: some View {
        Button {
            if storeManager.isFeatureUnlocked(.journal) {
                saveToJournal()
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                Text("Save to Journal")
            }
        }
        .buttonStyle(PrimaryButtonStyle(color: .greenSecondary))
        .padding(.top, 8)
    }

    private func saveToJournal() {
        let observation = PlantObservation(
            plantScientificName: plant.scientificName,
            date: .now,
            notes: "Saved from plant profile: \(plant.commonName)"
        )
        modelContext.insert(observation)
    }
}

// MARK: - Hashable Conformance for Navigation

extension Plant: Hashable {
    static func == (lhs: Plant, rhs: Plant) -> Bool {
        lhs.scientificName == rhs.scientificName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(scientificName)
    }
}

#Preview {
    NavigationStack {
        PlantDetailView(
            plant: Plant(
                scientificName: "Quercus robur",
                commonName: "English Oak",
                familyLatin: "Fagaceae",
                plantDescription: "A large deciduous tree native to most of Europe and into western Asia.",
                kingdom: "Plantae",
                taxonomicClass: "Magnoliopsida",
                order: "Fagales",
                genus: "Quercus",
                isFree: true,
                isAtRisk: true,
                atRiskStatus: "Vulnerable"
            )
        )
        .environmentObject(StoreManager())
    }
}
