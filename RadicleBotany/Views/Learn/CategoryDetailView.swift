import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    let category: String
    var accentColor: Color = .orangePrimary

    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]
    @Query(sort: \BotanyTerm.term) private var allTerms: [BotanyTerm]

    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 = Terms, 1 = Species
    @State private var selectedTermSubcategory: String? = nil
    @State private var selectedSpeciesTrait: String? = nil
    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    private let singleColumn = [
        GridItem(.flexible())
    ]

    // MARK: - Category → Term Category Mapping

    /// The BotanyTerm categories that belong to this organ category.
    private var termCategoryKeywords: [String] {
        switch category {
        case "Flowers":
            return ["flower", "floral", "petal", "sepal", "anther", "stamen",
                    "staminode", "carpel", "ovary", "style", "corolla",
                    "perianth", "inflorescence", "bract", "bracteole", "spathe"]
        case "Leaves":
            return ["leaf", "leaves", "leaf-like", "stipule", "stipellae", "marginal"]
        case "Fruits":
            return ["fruit", "seed", "cone", "dehiscent", "pericarp"]
        case "Bark", "Stems":
            return ["stem", "growth"]
        case "Roots":
            return ["root", "parasitism"]
        default:
            return []
        }
    }

    private func termMatchesCategory(_ term: BotanyTerm) -> Bool {
        let lower = term.category.lowercased()
        return termCategoryKeywords.contains { lower.contains($0) }
    }

    // MARK: - Trait Definitions (Plant keyPaths)

    private var traitDefinitions: [(label: String, keyPath: KeyPath<Plant, String?>)] {
        switch category {
        case "Flowers":
            return [
                ("Color", \Plant.flowerColor),
                ("Symmetry", \Plant.flowerSymmetry),
                ("Petal Count", \Plant.flowerPetalCount),
                ("Inflorescence", \Plant.flowerInflorescence),
                ("Petal Fusion", \Plant.flowerPetalFusion),
                ("Ovary Position", \Plant.flowerOvaryPosition),
                ("Sepal Presence", \Plant.flowerSepalPresence),
                ("Floral Sex", \Plant.flowerSexuality)
            ]
        case "Leaves":
            return [
                ("Type", \Plant.leafType),
                ("Shape", \Plant.leafShape),
                ("Arrangement", \Plant.leafArrangement),
                ("Margin", \Plant.leafMargin),
                ("Venation", \Plant.leafVenation),
                ("Apex", \Plant.leafApex),
                ("Base", \Plant.leafBase),
                ("Texture", \Plant.leafTexture)
            ]
        case "Fruits":
            return [
                ("Fruit Type", \Plant.fruitType),
                ("Seed Trait", \Plant.fruitSeedTrait)
            ]
        case "Bark", "Stems":
            return [
                ("Habit", \Plant.stemHabit),
                ("Structure", \Plant.stemStructure),
                ("Branching", \Plant.stemBranching)
            ]
        case "Roots":
            return [
                ("Root Type", \Plant.rootType)
            ]
        default:
            return []
        }
    }

    // MARK: - Terms Data

    /// All botany terms matching this category.
    private var categoryTerms: [BotanyTerm] {
        allTerms.filter { termMatchesCategory($0) }
    }

    /// Unique subcategories for terms in this category.
    private var termSubcategories: [String] {
        let cats = Set(categoryTerms.map { $0.category })
        return cats.sorted()
    }

    /// Terms filtered by search and subcategory.
    private var filteredTerms: [BotanyTerm] {
        var result = categoryTerms

        if let sub = selectedTermSubcategory {
            result = result.filter { $0.category == sub }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.term.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    /// Filtered terms grouped by subcategory.
    private var termsBySubcategory: [(name: String, terms: [BotanyTerm])] {
        let grouped = Dictionary(grouping: filteredTerms) { $0.category }
        return grouped
            .map { (name: $0.key, terms: $0.value.sorted { $0.term < $1.term }) }
            .sorted { $0.name < $1.name }
    }

    /// Terms with illustrations (color or diagram).
    private var illustratedTerms: [BotanyTerm] {
        filteredTerms.filter {
            ($0.colorImageURL != nil && !($0.colorImageURL?.isEmpty ?? true)) ||
            ($0.imageURL != nil && !($0.imageURL?.isEmpty ?? true))
        }
    }

    /// Terms without any illustration.
    private var textOnlyTerms: [BotanyTerm] {
        filteredTerms.filter {
            ($0.colorImageURL == nil || ($0.colorImageURL?.isEmpty ?? true)) &&
            ($0.imageURL == nil || ($0.imageURL?.isEmpty ?? true))
        }
    }

    // MARK: - Species Data

    /// All plants with at least one trait for this category.
    private var categoryPlants: [Plant] {
        allPlants.filter { plant in
            traitDefinitions.contains { def in
                let val = plant[keyPath: def.keyPath]
                return val != nil && !(val?.isEmpty ?? true)
            }
        }
    }

    /// Primary trait values for species filter chips.
    private var speciesTraitValues: [String] {
        guard let primary = traitDefinitions.first else { return [] }
        let values = Set(categoryPlants.compactMap { $0[keyPath: primary.keyPath] }.filter { !$0.isEmpty })
        return values.sorted()
    }

    /// Species filtered by search and trait.
    private var filteredPlants: [Plant] {
        var result = categoryPlants

        if let trait = selectedSpeciesTrait, let primary = traitDefinitions.first {
            result = result.filter { plant in
                guard let val = plant[keyPath: primary.keyPath] else { return false }
                return val == trait
            }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.scientificName.localizedCaseInsensitiveContains(searchText) ||
                $0.commonName.localizedCaseInsensitiveContains(searchText) ||
                $0.familyLatin.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            tabPicker
            filterBar

            ScrollView {
                if selectedTab == 0 {
                    termsContent
                } else {
                    speciesContent
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.categoryDetail)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.textMuted)

            TextField(selectedTab == 0 ? "Search terms..." : "Search species...", text: $searchText)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "Terms", subtitle: "\(categoryTerms.count)", index: 0)
            tabButton(title: "Species", subtitle: "\(categoryPlants.count)", index: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func tabButton(title: String, subtitle: String, index: Int) -> some View {
        let isActive = selectedTab == index

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                searchText = ""
            }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(isActive ? AppColors.textPrimary : AppColors.textMuted)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(isActive ? accentColor : AppColors.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isActive ? accentColor.opacity(0.15) : AppColors.cardElevated)
                        .clipShape(Capsule())
                }

                // Active indicator
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? accentColor : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private var filterBar: some View {
        if selectedTab == 0 && termSubcategories.count > 1 {
            // Term subcategory filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", isSelected: selectedTermSubcategory == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTermSubcategory = nil }
                    }

                    ForEach(termSubcategories, id: \.self) { sub in
                        filterChip(title: sub, isSelected: selectedTermSubcategory == sub) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTermSubcategory = selectedTermSubcategory == sub ? nil : sub
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        } else if selectedTab == 1 && speciesTraitValues.count > 1 {
            // Species trait filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", isSelected: selectedSpeciesTrait == nil) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedSpeciesTrait = nil }
                    }

                    ForEach(speciesTraitValues, id: \.self) { trait in
                        filterChip(title: trait, isSelected: selectedSpeciesTrait == trait) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSpeciesTrait = selectedSpeciesTrait == trait ? nil : trait
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let bgColor: Color = isSelected ? accentColor : AppColors.cardElevated
        let fgColor: Color = isSelected ? .white : AppColors.textSecondary
        let borderColor: Color = isSelected ? accentColor : AppColors.border

        return Button(action: action) {
            Text(title)
                .font(AppTypography.tagText)
                .foregroundStyle(fgColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(borderColor, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Terms Content

    private var termsContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if filteredTerms.isEmpty {
                emptyState(icon: "text.book.closed", message: "No terms found")
            } else {
                termsResultBar

                // 1. Illustrated terms — 2-column grid with images
                if !illustratedTerms.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(accentColor.opacity(0.7))

                        Text("Illustrated")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textSecondary)

                        Text("\(illustratedTerms.count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(illustratedTerms) { term in
                            termCell(term)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // 2. Text-only terms — clean list rows
                if !textOnlyTerms.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "text.book.closed")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted.opacity(0.7))

                        Text("Definitions")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textSecondary)

                        Text("\(textOnlyTerms.count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, illustratedTerms.isEmpty ? 12 : 24)
                    .padding(.bottom, 6)

                    LazyVStack(spacing: 6) {
                        ForEach(textOnlyTerms) { term in
                            textOnlyTermCell(term)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Color.clear.frame(height: 120)
            }
        }
    }

    private var termsResultBar: some View {
        HStack(spacing: 4) {
            Text("\(filteredTerms.count) terms")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)

            if illustratedTerms.count > 0 && illustratedTerms.count < filteredTerms.count {
                Text("· \(illustratedTerms.count) illustrated")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            if selectedTermSubcategory != nil || !searchText.isEmpty {
                Text("·")
                    .foregroundStyle(AppColors.textMuted)
                Button {
                    selectedTermSubcategory = nil
                    searchText = ""
                } label: {
                    Text("Clear")
                        .font(AppTypography.tagText)
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Term Cell

    @ViewBuilder
    private func termCell(_ term: BotanyTerm) -> some View {
        let hasImage = (term.colorImageURL != nil && !(term.colorImageURL?.isEmpty ?? true)) ||
                       (term.imageURL != nil && !(term.imageURL?.isEmpty ?? true))

        let allFiltered = filteredTerms
        let index = allFiltered.firstIndex(where: { $0.id == term.id }) ?? 0
        NavigationLink(destination: CollectionPagerView(items: allFiltered, startIndex: index) { t in
            TermDetailView(term: t)
        }) {
            termCellContent(term, hasImage: hasImage, isLocked: false)
        }
        .buttonStyle(.plain)
    }

    private func termCellContent(_ term: BotanyTerm, hasImage: Bool, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Image or placeholder
            ZStack {
                let bestURL: URL? = {
                    if let c = term.colorImageURL, !c.isEmpty, let u = URL(string: c) { return u }
                    if let d = term.imageURL, !d.isEmpty, let u = URL(string: d) { return u }
                    return nil
                }()
                if hasImage, let url = bestURL {
                    AppColors.appBackground
                        .overlay {
                            ThrottledAsyncImage(url: url, contentMode: .fit) {
                                termImagePlaceholder
                            }
                        }
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                } else {
                    AppColors.cardElevated
                        .overlay { termImagePlaceholder }
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }

                if isLocked {
                    LockOverlay()
                        .frame(height: 90)
                }
            }

            // Term name
            Text(term.term)
                .font(AppTypography.tagText)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            // Short description
            if !term.descriptionShort.isEmpty {
                Text(term.descriptionShort)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(.bottom, 4)
    }

    private func textOnlyTermCell(_ term: BotanyTerm) -> some View {
        let allFiltered = filteredTerms
        let index = allFiltered.firstIndex(where: { $0.id == term.id }) ?? 0
        return NavigationLink(destination: CollectionPagerView(items: allFiltered, startIndex: index) { t in
            TermDetailView(term: t)
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(term.term)
                        .font(AppTypography.tagText)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    if !term.descriptionShort.isEmpty {
                        Text(term.descriptionShort)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textMuted.opacity(0.4))
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private var termImagePlaceholder: some View {
        Image(systemName: categoryIcon)
            .font(.title3)
            .foregroundStyle(AppColors.textMuted.opacity(0.3))
    }

    // MARK: - Species Content

    private var speciesContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if filteredPlants.isEmpty {
                emptyState(icon: categoryIcon, message: "No species found")
            } else {
                // Result count
                speciesResultBar

                // Species grid — single column for text-only items
                LazyVGrid(columns: singleColumn, spacing: 8) {
                    ForEach(filteredPlants) { plant in
                        speciesCell(plant)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
        }
    }

    private var speciesResultBar: some View {
        HStack(spacing: 6) {
            Text("\(filteredPlants.count) species")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)

            if selectedSpeciesTrait != nil || !searchText.isEmpty {
                Text("·")
                    .foregroundStyle(AppColors.textMuted)
                Button {
                    selectedSpeciesTrait = nil
                    searchText = ""
                } label: {
                    Text("Clear")
                        .font(AppTypography.tagText)
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            let fCount = Set(filteredPlants.map { $0.familyLatin }).count
            Text("\(fCount) families")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Species Cell

    private func speciesCell(_ plant: Plant) -> some View {
        let plants = filteredPlants
        let index = plants.firstIndex(where: { $0.id == plant.id }) ?? 0
        return NavigationLink(destination: CollectionPagerView(items: plants, startIndex: index) { p in
            PlantDetailView(plant: p)
        }) {
            speciesCellContent(plant: plant, isLocked: false)
        }
        .buttonStyle(.plain)
    }

    private func speciesCellContent(plant: Plant, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero area
            ZStack(alignment: .bottomLeading) {
                ZStack {
                    accentColor.opacity(0.06)
                    Image(systemName: categoryIcon)
                        .font(AppTypography.inter(size: 28))
                        .foregroundStyle(accentColor.opacity(0.15))
                }
                .frame(height: 70)

                if isLocked {
                    Color.black.opacity(0.5)
                        .frame(height: 70)
                        .overlay {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.white.opacity(0.6))
                                .font(AppTypography.bodyText)
                        }
                }

                // Primary trait badge
                if let val = primaryTraitValue(for: plant) {
                    Text(val)
                        .font(AppTypography.caption)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.15))
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.scientificName)
                    .font(AppTypography.fieldLabel)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(plant.titleCasedCommonName)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                traitPills(for: plant)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func traitPills(for plant: Plant) -> some View {
        let traits = relevantTraits(for: plant)
        if !traits.isEmpty {
            HStack(spacing: 4) {
                ForEach(traits.prefix(2), id: \.label) { trait in
                    Text(trait.value)
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.cardElevated)
                        .clipShape(Capsule())
                }
                if traits.count > 2 {
                    Text("+\(traits.count - 2)")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.cardElevated)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 3)
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: icon)
                .font(AppTypography.inter(size: 40))
                .foregroundStyle(accentColor.opacity(0.4))

            Text(message)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)

            if !searchText.isEmpty || selectedTermSubcategory != nil || selectedSpeciesTrait != nil {
                Button {
                    searchText = ""
                    selectedTermSubcategory = nil
                    selectedSpeciesTrait = nil
                } label: {
                    Text("Clear filters")
                        .font(AppTypography.tagText)
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var categoryIcon: String {
        switch category {
        case "Flowers": return "camera.macro"
        case "Leaves": return "leaf.fill"
        case "Fruits": return "drop.fill"
        case "Bark": return "tree.fill"
        case "Stems": return "laurel.leading"
        case "Roots": return "carrot.fill"
        default: return "leaf.fill"
        }
    }

    private func primaryTraitValue(for plant: Plant) -> String? {
        guard let primary = traitDefinitions.first else { return nil }
        let val = plant[keyPath: primary.keyPath]
        guard let val, !val.isEmpty else { return nil }
        return val
    }

    private func relevantTraits(for plant: Plant) -> [(label: String, value: String)] {
        traitDefinitions.dropFirst().compactMap { def in
            guard let val = plant[keyPath: def.keyPath], !val.isEmpty else { return nil }
            return (label: def.label, value: val)
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: "Flowers", accentColor: .orangePrimary)
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, BotanyTerm.self], inMemory: true)
    .preferredColorScheme(.dark)
}
