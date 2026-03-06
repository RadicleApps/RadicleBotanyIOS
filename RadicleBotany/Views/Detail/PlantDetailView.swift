import SwiftUI
import SwiftData
import MapKit

struct PlantDetailView: View {
    let plant: Plant

    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query private var allPlants: [Plant]
    @Query private var allFamilies: [Family]
    @Query private var allObservations: [PlantObservation]

    @State private var relatedSearchText = ""
    @State private var selectedGenus: String? = nil
    @State private var isDescriptionExpanded = false
    @State private var showSavedConfirmation = false
    @State private var fullscreenImage: ImageSource? = nil
    @State private var fullscreenCaption: String? = nil

    // MARK: - Filtered Data

    private var familyMatch: Family? {
        allFamilies.first { $0.familyLatin == plant.familyLatin }
    }

    private var relatedSpecies: [Plant] {
        allPlants.filter { $0.familyLatin == plant.familyLatin && $0.scientificName != plant.scientificName }
    }

    private var filteredRelatedSpecies: [Plant] {
        var result = relatedSpecies

        if let genus = selectedGenus {
            result = result.filter { $0.genus == genus }
        }

        if !relatedSearchText.isEmpty {
            result = result.filter {
                $0.scientificName.localizedCaseInsensitiveContains(relatedSearchText) ||
                $0.commonName.localizedCaseInsensitiveContains(relatedSearchText) ||
                $0.genus.localizedCaseInsensitiveContains(relatedSearchText)
            }
        }

        return result
    }

    private var relatedGenera: [String] {
        let genera = Set(relatedSpecies.map(\.genus).filter { !$0.isEmpty })
        return genera.sorted()
    }

    private var observedScientificNames: Set<String> {
        Set(allObservations.compactMap { $0.plantScientificName })
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero: full-bleed, no horizontal padding
                    heroSection

                    // Content below hero
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        organImageGallery
                        // Description hidden until all species have descriptions
                        // descriptionSection
                        traitsSection
                        distributionMapSection
                        relatedSpeciesSection
                        saveToJournalSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }

            // Floating flashcard study button
            NavigationLink(destination: PlantFlashcardView(familyFilter: plant.familyLatin).navigationTitle("\(plant.familyLatin) Species").navigationBarTitleDisplayMode(.inline)) {
                VStack(spacing: 3) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(AppTypography.inter(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 44, height: 44)
                        .background(AppColors.success.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.success.opacity(0.4), lineWidth: 1.5)
                        )

                    Text("Study")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .background(AppColors.appBackground)
        .navigationTitle(plant.commonName)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $fullscreenImage) { source in
            FullscreenImageViewer(source: source, caption: fullscreenCaption)
        }
        .task {
            // Request location early so GPS coordinates are available for "Save to Journal"
            LocationManager.shared.requestLocation()

            // Lazily cache this plant's image for offline access.
            // Only runs if the plant has a URL but no locally cached data yet.
            if plant.cachedImageData == nil, let urlString = plant.bestImageURL, let url = URL(string: urlString) {
                await DataLoader.shared.cacheSinglePlantImage(plant: plant, modelContext: modelContext)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Image: full-bleed, no border
            CachedPlantHeroImage(plant: plant, height: 260)

            // Gradient scrim for seamless transition
            LinearGradient(
                colors: [.clear, .clear, AppColors.appBackground.opacity(0.6), AppColors.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            // Bottom-left info overlays
            HStack(spacing: 8) {
                if !plant.genus.isEmpty {
                    Text(plant.genus)
                        .font(AppTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                if plant.isAtRisk, let status = plant.atRiskStatus {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(AppTypography.inter(size: 9))
                        Text(status)
                            .font(AppTypography.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (status == "Critical" ? AppColors.error : AppColors.warning).opacity(0.8)
                    )
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(height: 260)
    }

    /// Minimal placeholder for mini species cards
    private var miniPlantPlaceholder: some View {
        AppColors.cardElevated.opacity(0.3)
            .frame(width: 140, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay {
                Image(systemName: "leaf.fill")
                    .font(AppTypography.inter(size: 20))
                    .foregroundStyle(AppColors.success.opacity(0.12))
            }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plant.scientificName)
                .font(.system(size: 26, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(AppColors.textPrimary)

            Text(plant.commonName)
                .font(AppTypography.displayMedium)
                .foregroundStyle(AppColors.textSecondary)

            if let altNames = plant.alternativeCommonNames, !altNames.isEmpty {
                Text("Also known as: \(altNames)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            HStack(spacing: 8) {
                if let family = familyMatch {
                    NavigationLink(destination: FamilyDetailView(family: family)) {
                        CategoryPill(text: plant.familyLatin, color: .orangePrimary)
                    }
                } else {
                    CategoryPill(text: plant.familyLatin, color: .orangePrimary)
                }

                if plant.isAtRisk {
                    AtRiskBadge(status: plant.atRiskStatus ?? "At-Risk")
                }

            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(markdownToAttributed(plant.plantDescription))
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)
                .lineLimit(isDescriptionExpanded ? nil : 3)

            if !isDescriptionExpanded {
                HStack {
                    Spacer()
                    Text("Read more")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.success)
                        .padding(.top, 6)
                }
            } else {
                HStack {
                    Spacer()
                    Text("Show less")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.success)
                        .padding(.top, 6)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDescriptionExpanded.toggle()
            }
        }
    }

    // MARK: - Traits

    // MARK: - Organ Image Gallery

    @ViewBuilder
    private var organImageGallery: some View {
        let images = plant.organImages
        if !images.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(images, id: \.organ) { item in
                            organImageCard(organ: item.organ, urlString: item.url)
                        }
                    }
                }
            }
        }
    }

    private func organImageCard(organ: PlantOrgan, urlString: String) -> some View {
        VStack(spacing: 6) {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    default:
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .fill(organ.color.opacity(0.06))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: organ.icon)
                                    .font(.title2)
                                    .foregroundStyle(organ.color.opacity(0.2))
                            }
                    }
                }
            }

        }
        .frame(width: 120)
        .contentShape(Rectangle())
        .onTapGesture {
            fullscreenImage = .url(urlString)
            fullscreenCaption = plant.commonName
        }
    }

    // MARK: - Traits

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAITS")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .kerning(1.8)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                traitDisclosureGroup(title: "Leaf Traits", icon: "leaf.fill", traits: leafTraits, organ: .leaf)
                traitDivider
                traitDisclosureGroup(title: "Stem Traits", icon: "laurel.leading", traits: stemTraits, organ: .stem)
                traitDivider
                traitDisclosureGroup(title: "Flower Traits", icon: "camera.macro", traits: flowerTraits, organ: .flower)
                traitDivider
                traitDisclosureGroup(title: "Fruit Traits", icon: "drop.fill", traits: fruitTraits, organ: .fruit)
                traitDivider
                traitDisclosureGroup(title: "Root Traits", icon: "carrot.fill", traits: rootTraits, organ: nil)
                traitDivider
                traitDisclosureGroup(title: "Habitat", icon: "mountain.2.fill", traits: habitatTraits, organ: .habit)
                traitDivider
                traitDisclosureGroup(title: "Bark", icon: "tree.fill", traits: [], organ: .bark)
            }
        }
    }

    private var traitDivider: some View {
        Divider()
            .background(AppColors.border.opacity(0.5))
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
    private func traitDisclosureGroup(title: String, icon: String, traits: [(String, String)], organ: PlantOrgan? = nil) -> some View {
        if !traits.isEmpty {
            DisclosureGroup {
                VStack(spacing: 0) {
                    ForEach(Array(traits.enumerated()), id: \.offset) { index, trait in
                        traitRow(name: trait.0, value: trait.1)

                        if index < traits.count - 1 {
                            Divider()
                                .background(AppColors.border)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 24)

                    Text(title)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Text("\(traits.count)")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            .tint(AppColors.textSecondary)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
    }

    private func traitRow(name: String, value: String) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(value)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Distribution Map

    private var userObservationsForThisPlant: [PlantObservation] {
        allObservations.filter {
            $0.plantScientificName == plant.scientificName &&
            $0.latitude != nil && $0.longitude != nil
        }
    }

    @ViewBuilder
    private var distributionMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup {
                SpeciesMapView(
                    plant: plant,
                    userObservations: userObservationsForThisPlant
                )
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 24)

                    Text("Distribution Map")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    Image(systemName: "mappin.and.ellipse")
                        .font(AppTypography.inter(size: 9))
                        .foregroundStyle(AppColors.success.opacity(0.5))

                    Spacer()
                }
            }
            .tint(AppColors.textSecondary)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Related Species (with search + genus filter)

    @ViewBuilder
    private var relatedSpeciesSection: some View {
        if !relatedSpecies.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                // Header with count
                CollectionHeader(
                    icon: "leaf.fill",
                    title: "Related Species",
                    count: filteredRelatedSpecies.count,
                    total: relatedSpecies.count,
                    color: .greenSecondary
                )

                // Inline search (show when more than 4 species)
                if relatedSpecies.count > 4 {
                    InlineSearchField(
                        text: $relatedSearchText,
                        placeholder: "Search related species..."
                    )
                }

                // Genus filter chips
                if relatedGenera.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            MiniFilterChip(name: "All", isSelected: selectedGenus == nil, color: .greenSecondary) {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedGenus = nil }
                            }
                            ForEach(relatedGenera, id: \.self) { genus in
                                MiniFilterChip(name: genus, isSelected: selectedGenus == genus, color: .greenSecondary) {
                                    withAnimation(.easeInOut(duration: 0.15)) { selectedGenus = genus }
                                }
                            }
                        }
                    }
                }

                // Results
                if filteredRelatedSpecies.isEmpty {
                    MiniEmptyState(icon: "leaf", text: "No matching species", color: .greenSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(filteredRelatedSpecies, id: \.scientificName) { relatedPlant in
                                NavigationLink(destination: PlantDetailView(plant: relatedPlant)) {
                                    relatedSpeciesCard(relatedPlant)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func relatedSpeciesCard(_ relatedPlant: Plant) -> some View {
        let hasObservation = observedScientificNames.contains(relatedPlant.scientificName)

        return VStack(alignment: .leading, spacing: 0) {
            // Image area — borderless
            ZStack(alignment: .bottomLeading) {
                if let cachedImage = relatedPlant.cachedImage {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                } else if let imageURL = relatedPlant.bestImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 140, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                        default:
                            miniPlantPlaceholder
                        }
                    }
                } else {
                    miniPlantPlaceholder
                }

                if !relatedPlant.genus.isEmpty {
                    Text(relatedPlant.genus)
                        .font(AppTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }

            // Observed indicator: thin green line below image
            if hasObservation {
                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.success)
                    .frame(height: 2)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }

            // Plant info
            VStack(alignment: .leading, spacing: 2) {
                Text(relatedPlant.scientificName)
                    .font(AppTypography.fieldLabel)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(relatedPlant.commonName)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                if relatedPlant.isAtRisk, let status = relatedPlant.atRiskStatus {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(AppTypography.inter(size: 8))
                        Text(status)
                            .font(AppTypography.caption)
                    }
                    .foregroundStyle(status == "Critical" ? AppColors.error : AppColors.warning)
                }
            }
            .padding(.top, 6)
        }
        .frame(width: 140)
    }

    // MARK: - Save to Journal

    private var saveToJournalSection: some View {
        Button {
            saveToJournal()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showSavedConfirmation ? "checkmark.circle.fill" : "square.and.pencil")
                Text(showSavedConfirmation ? "Saved to Journal" : "Save to Journal")
            }
        }
        .buttonStyle(PrimaryButtonStyle(color: showSavedConfirmation ? .successGreen : .purpleSecondary))
        .disabled(showSavedConfirmation)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: showSavedConfirmation)
    }

    private func saveToJournal() {
        let currentLocation = LocationManager.shared.location
        let observation = PlantObservation(
            plantScientificName: plant.scientificName,
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude,
            date: .now,
            notes: "Saved from plant profile: \(plant.commonName)"
        )
        modelContext.insert(observation)
        showSavedConfirmation = true

        // Auto-dismiss after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSavedConfirmation = false
        }
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
        .environmentObject(StoreManager(preview: true))
    }
}
