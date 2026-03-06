import SwiftUI
import SwiftData

struct TermDetailView: View {
    let term: BotanyTerm

    @Query private var allPlants: [Plant]
    @Query private var allFamilies: [Family]
    @Query private var allTerms: [BotanyTerm]

    // MARK: - Search & Filter State

    @State private var familySearchText = ""
    @State private var speciesSearchText = ""
    @State private var relatedSearchText = ""
    @State private var selectedTraitCategory: String? = nil
    @State private var isDescriptionExpanded = false

    // MARK: - Base Data (trait-matched)

    private var speciesWithTrait: [Plant] {
        let searchValue = term.term.lowercased()
        return allPlants.filter { plant in
            matchesAnyPlantTrait(plant: plant, value: searchValue)
        }
    }

    private var familiesWithTrait: [Family] {
        let searchValue = term.term.lowercased()
        return allFamilies.filter { family in
            matchesAnyFamilyTrait(family: family, value: searchValue)
        }
    }

    private var relatedTerms: [BotanyTerm] {
        allTerms.filter { $0.category == term.category && $0.term != term.term }
    }

    // MARK: - Filtered Data

    private var filteredFamilies: [Family] {
        var result = familiesWithTrait

        if let traitCat = selectedTraitCategory {
            let searchValue = term.term.lowercased()
            result = result.filter { family in
                let traits = allFamilyTraitPairs(family)
                return traits.contains { label, value in
                    guard let value = value, !value.isEmpty else { return false }
                    return label == traitCat && value.localizedCaseInsensitiveContains(searchValue)
                }
            }
        }

        if !familySearchText.isEmpty {
            result = result.filter {
                $0.familyLatin.localizedCaseInsensitiveContains(familySearchText) ||
                $0.familyEnglish.localizedCaseInsensitiveContains(familySearchText) ||
                $0.order.localizedCaseInsensitiveContains(familySearchText)
            }
        }

        return result
    }

    private var filteredSpecies: [Plant] {
        guard !speciesSearchText.isEmpty else { return speciesWithTrait }
        return speciesWithTrait.filter {
            $0.scientificName.localizedCaseInsensitiveContains(speciesSearchText) ||
            $0.commonName.localizedCaseInsensitiveContains(speciesSearchText) ||
            $0.familyLatin.localizedCaseInsensitiveContains(speciesSearchText) ||
            $0.genus.localizedCaseInsensitiveContains(speciesSearchText)
        }
    }

    private var filteredRelatedTerms: [BotanyTerm] {
        guard !relatedSearchText.isEmpty else { return relatedTerms }
        return relatedTerms.filter {
            $0.term.localizedCaseInsensitiveContains(relatedSearchText) ||
            $0.descriptionShort.localizedCaseInsensitiveContains(relatedSearchText)
        }
    }

    /// Unique trait categories that match this term across all matched families
    private var matchingTraitCategories: [String] {
        let searchValue = term.term.lowercased()
        var categories = Set<String>()
        for family in familiesWithTrait {
            for (label, value) in allFamilyTraitPairs(family) {
                guard let value = value, !value.isEmpty else { continue }
                if value.localizedCaseInsensitiveContains(searchValue) {
                    categories.insert(label)
                }
            }
        }
        return categories.sorted()
    }

    /// Category icon based on term category
    private var categoryIcon: String {
        switch term.category.lowercased() {
        case let c where c.contains("leaf"): return "leaf.fill"
        case let c where c.contains("flower") || c.contains("floral") || c.contains("petal") || c.contains("sepal"): return "camera.macro"
        case let c where c.contains("fruit") || c.contains("seed"): return "drop.fill"
        case let c where c.contains("stem"): return "laurel.leading"
        case let c where c.contains("root"): return "carrot.fill"
        case let c where c.contains("habitat") || c.contains("growth"): return "mountain.2.fill"
        default: return "text.book.closed.fill"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero illustration: no horizontal padding, floats on dark bg
                illustrationSection

                // Content below illustration
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    descriptionSection
                    familiesWithTraitSection
                    speciesWithTraitSection
                    relatedTermsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle(term.term)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Decorative accent line
            RoundedRectangle(cornerRadius: 1)
                .fill(AppColors.brandPurple.opacity(0.3))
                .frame(width: 40, height: 2)

            Text(term.term)
                .font(AppTypography.inter(size: 28, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(AppTypography.inter(size: 12))
                    .foregroundStyle(AppColors.brandPurple)
                CategoryPill(text: term.category, color: .purpleSecondary)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Illustration

    private var illustrationSection: some View {
        Group {
            if let imageURL = term.imageURL, let url = URL(string: imageURL) {
                illustrationAsyncImage(url: url)
            } else {
                // Minimal placeholder — category icon floating on dark bg
                VStack(spacing: 8) {
                    Image(systemName: categoryIcon)
                        .font(AppTypography.inter(size: 48, weight: .thin))
                        .foregroundStyle(AppColors.brandPurple.opacity(0.2))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            }
        }
    }

    @ViewBuilder
    private func illustrationAsyncImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .tint(AppColors.brandPurple.opacity(0.5))
                    )
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 280)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: categoryIcon)
                        .font(AppTypography.inter(size: 48, weight: .thin))
                        .foregroundStyle(AppColors.brandPurple.opacity(0.2))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            @unknown default:
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !term.descriptionShort.isEmpty {
                Text(markdownToAttributed(term.descriptionShort))
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(5)
            }

            if !term.descriptionLong.isEmpty {
                Text(markdownToAttributed(term.descriptionLong))
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(5)
                    .lineLimit(isDescriptionExpanded ? nil : 3)
                    .padding(.top, term.descriptionShort.isEmpty ? 0 : 10)
            }

            if term.descriptionShort.isEmpty && term.descriptionLong.isEmpty {
                Text("Botanical term in the \(term.category) category.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(5)
            }

            if !term.descriptionLong.isEmpty {
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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDescriptionExpanded.toggle()
            }
        }
    }

    // MARK: - Families with this Trait (with search + trait category filter)

    @ViewBuilder
    private var familiesWithTraitSection: some View {
        if !familiesWithTrait.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CollectionHeader(
                    icon: "leaf.circle.fill",
                    title: "Families with this Trait",
                    count: filteredFamilies.count,
                    total: familiesWithTrait.count,
                    color: .orangePrimary
                )

                if familiesWithTrait.count > 3 {
                    InlineSearchField(
                        text: $familySearchText,
                        placeholder: "Search families..."
                    )
                }

                if matchingTraitCategories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            MiniFilterChip(name: "All", isSelected: selectedTraitCategory == nil, color: .orangePrimary) {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedTraitCategory = nil }
                            }
                            ForEach(matchingTraitCategories, id: \.self) { category in
                                MiniFilterChip(name: category, isSelected: selectedTraitCategory == category, color: .orangePrimary) {
                                    withAnimation(.easeInOut(duration: 0.15)) { selectedTraitCategory = category }
                                }
                            }
                        }
                    }
                }

                if filteredFamilies.isEmpty {
                    MiniEmptyState(icon: "leaf.circle", text: "No matching families", color: .orangePrimary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(filteredFamilies, id: \.familyLatin) { family in
                                NavigationLink(destination: FamilyDetailView(family: family)) {
                                    familyCard(family)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func familyCard(_ family: Family) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thin accent line
            RoundedRectangle(cornerRadius: 1)
                .fill(AppColors.primaryAmber.opacity(0.2))
                .frame(height: 1.5)

            // Matching trait pill
            if let matchingTrait = familyMatchingTrait(family) {
                Text(matchingTrait)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.primaryAmber)
                    .padding(.top, 8)
            }

            // Family info
            VStack(alignment: .leading, spacing: 3) {
                Text(family.familyLatin)
                    .font(AppTypography.tagText)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(family.familyEnglish)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                let speciesCount = allPlants.filter { $0.familyLatin == family.familyLatin }.count
                if speciesCount > 0 {
                    Text("\(speciesCount) species")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .padding(.top, 1)
                }
            }
            .padding(.top, 8)
        }
        .frame(width: 140)
    }

    /// Returns the specific trait category that matches (e.g. "Leaf Arrangement") for display in the card.
    private func familyMatchingTrait(_ family: Family) -> String? {
        let searchValue = term.term.lowercased()
        let familyTraits: [(String, String?)] = allFamilyTraitPairs(family)
        for (label, value) in familyTraits {
            guard let value = value, !value.isEmpty else { continue }
            if value.localizedCaseInsensitiveContains(searchValue) {
                return label
            }
        }
        return nil
    }

    // MARK: - Species with this Trait (with search)

    @ViewBuilder
    private var speciesWithTraitSection: some View {
        if !speciesWithTrait.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CollectionHeader(
                    icon: "leaf.fill",
                    title: "Species with this Trait",
                    count: filteredSpecies.count,
                    total: speciesWithTrait.count,
                    color: .greenSecondary
                )

                if speciesWithTrait.count > 3 {
                    InlineSearchField(
                        text: $speciesSearchText,
                        placeholder: "Search species..."
                    )
                }

                if filteredSpecies.isEmpty {
                    MiniEmptyState(icon: "leaf", text: "No matching species", color: .greenSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(filteredSpecies, id: \.scientificName) { plant in
                                NavigationLink(destination: PlantDetailView(plant: plant)) {
                                    speciesCard(plant)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func speciesCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area — borderless
            ZStack(alignment: .bottomLeading) {
                if let cachedImage = plant.cachedImage {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 140, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                        default:
                            speciesPlaceholder
                        }
                    }
                } else {
                    speciesPlaceholder
                }

                // Matching trait pill
                if let matchingTrait = plantMatchingTrait(plant) {
                    Text(matchingTrait)
                        .font(AppTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }

            // Info — directly on dark background
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.scientificName)
                    .font(AppTypography.fieldLabel)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(plant.commonName)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.top, 6)
        }
        .frame(width: 140)
    }

    /// Minimal placeholder for species cards
    private var speciesPlaceholder: some View {
        AppColors.cardElevated.opacity(0.3)
            .frame(width: 140, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay {
                Image(systemName: "leaf.fill")
                    .font(AppTypography.inter(size: 20))
                    .foregroundStyle(AppColors.success.opacity(0.12))
            }
    }

    /// Returns the specific trait category that matches for display in the species card.
    private func plantMatchingTrait(_ plant: Plant) -> String? {
        let searchValue = term.term.lowercased()
        let plantTraits: [(String, String?)] = allPlantTraitPairs(plant)
        for (label, value) in plantTraits {
            guard let value = value, !value.isEmpty else { continue }
            if value.localizedCaseInsensitiveContains(searchValue) {
                return label
            }
        }
        return nil
    }

    // MARK: - Related Terms (with search)

    @ViewBuilder
    private var relatedTermsSection: some View {
        if !relatedTerms.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CollectionHeader(
                    icon: "text.book.closed.fill",
                    title: "Related Terms",
                    count: filteredRelatedTerms.count,
                    total: relatedTerms.count,
                    color: .purpleSecondary
                )

                if relatedTerms.count > 3 {
                    InlineSearchField(
                        text: $relatedSearchText,
                        placeholder: "Search related terms..."
                    )
                }

                if filteredRelatedTerms.isEmpty {
                    MiniEmptyState(icon: "text.book.closed", text: "No matching terms", color: .purpleSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(filteredRelatedTerms, id: \.term) { relatedTerm in
                                NavigationLink(destination: TermDetailView(term: relatedTerm)) {
                                    termCard(relatedTerm)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func termCard(_ botanyTerm: BotanyTerm) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area — illustration floats on dark bg
            if let imageURL = botanyTerm.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 70)
                    default:
                        termPlaceholder
                    }
                }
            } else {
                termPlaceholder
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(botanyTerm.term)
                    .font(AppTypography.tagText)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(botanyTerm.category)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.brandPurple)
                    .lineLimit(1)
            }
            .padding(.top, 6)
        }
        .frame(width: 140)
    }

    /// Minimal placeholder for term cards
    private var termPlaceholder: some View {
        AppColors.brandPurple.opacity(0.05)
            .frame(width: 140, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay {
                Image(systemName: "text.book.closed.fill")
                    .font(AppTypography.inter(size: 18))
                    .foregroundStyle(AppColors.brandPurple.opacity(0.15))
            }
    }

    // MARK: - Trait Matching — Plants

    private func allPlantTraitPairs(_ plant: Plant) -> [(String, String?)] {
        [
            ("Leaf Type", plant.leafType),
            ("Leaf Attachment", plant.leafAttachment),
            ("Leaf Arrangement", plant.leafArrangement),
            ("Leaf Shape", plant.leafShape),
            ("Leaf Margin", plant.leafMargin),
            ("Leaf Apex", plant.leafApex),
            ("Leaf Base", plant.leafBase),
            ("Leaf Venation", plant.leafVenation),
            ("Leaf Texture", plant.leafTexture),
            ("Leaf Stipules", plant.leafStipules),
            ("Stem Habit", plant.stemHabit),
            ("Stem Structure", plant.stemStructure),
            ("Stem Branching", plant.stemBranching),
            ("Inflorescence", plant.flowerInflorescence),
            ("Flower Symmetry", plant.flowerSymmetry),
            ("Petal Count", plant.flowerPetalCount),
            ("Petal Fusion", plant.flowerPetalFusion),
            ("Sepal Presence", plant.flowerSepalPresence),
            ("Sepal Fusion", plant.flowerSepalFusion),
            ("Flower Color", plant.flowerColor),
            ("Flower Position", plant.flowerPosition),
            ("Ovary Position", plant.flowerOvaryPosition),
            ("Flower Sexuality", plant.flowerSexuality),
            ("Floral Part", plant.flowerFloralPart),
            ("Fruit Type", plant.fruitType),
            ("Seed Trait", plant.fruitSeedTrait),
            ("Root Type", plant.rootType)
        ]
    }

    private func matchesAnyPlantTrait(plant: Plant, value: String) -> Bool {
        allPlantTraitPairs(plant).contains { _, field in
            guard let field = field, !field.isEmpty else { return false }
            return field.localizedCaseInsensitiveContains(value)
        }
    }

    // MARK: - Trait Matching — Families

    private func allFamilyTraitPairs(_ family: Family) -> [(String, String?)] {
        [
            ("Leaf Type", family.leafType),
            ("Leaf Attachment", family.leafAttachment),
            ("Leaf Arrangement", family.leafArrangement),
            ("Leaf Shape", family.leafShape),
            ("Leaf Margin", family.leafMargin),
            ("Leaf Apex", family.leafApex),
            ("Leaf Base", family.leafBase),
            ("Leaf Venation", family.leafVenation),
            ("Leaf Texture", family.leafTexture),
            ("Leaf Stipules", family.leafStipules),
            ("Additional Trait", family.leafAdditionalTrait),
            ("Stem Habit", family.stemHabit),
            ("Stem Structure", family.stemStructure),
            ("Stem Branching", family.stemBranching),
            ("Inflorescence", family.flowerInflorescence),
            ("Flower Symmetry", family.flowerSymmetry),
            ("Petal Count", family.flowerPetalCount),
            ("Petal Fusion", family.flowerPetalFusion),
            ("Sepal Presence", family.flowerSepalPresence),
            ("Sepal Fusion", family.flowerSepalFusion),
            ("Flower Color", family.flowerColor),
            ("Flower Position", family.flowerPosition),
            ("Ovary Position", family.flowerOvaryPosition),
            ("Flower Sexuality", family.flowerSexuality),
            ("Floral Part", family.flowerFloralPart),
            ("Fruit Type", family.fruitType),
            ("Seed Trait", family.fruitSeedTrait),
            ("Root Type", family.rootType),
            ("Root Trait", family.rootTrait),
            ("Habitat", family.habitat),
            ("Soil", family.soil),
            ("Growth Habit", family.growthHabit)
        ]
    }

    private func matchesAnyFamilyTrait(family: Family, value: String) -> Bool {
        allFamilyTraitPairs(family).contains { _, field in
            guard let field = field, !field.isEmpty else { return false }
            return field.localizedCaseInsensitiveContains(value)
        }
    }
}

// MARK: - Hashable Conformance for BotanyTerm Navigation

extension BotanyTerm: Hashable {
    static func == (lhs: BotanyTerm, rhs: BotanyTerm) -> Bool {
        lhs.term == rhs.term
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(term)
    }
}

#Preview {
    NavigationStack {
        TermDetailView(
            term: BotanyTerm(
                term: "Alternate",
                category: "Leaf Arrangement",
                descriptionShort: "A leaf arrangement in which a single leaf arises at each node, alternating sides along the stem.",
                descriptionLong: "This creates a staggered pattern, where no two leaves are directly opposite each other. The pattern may be spiral, helical, or simply zigzag, depending on the species.",
                imageURL: nil,
                showPlantID: true,
                isFree: true
            )
        )
    }
    .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self], inMemory: true)
    .preferredColorScheme(.dark)
}
