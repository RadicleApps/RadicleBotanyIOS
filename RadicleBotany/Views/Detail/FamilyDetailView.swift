import SwiftUI
import SwiftData

struct FamilyDetailView: View {
    let family: Family

    @Query private var allPlants: [Plant]
    @Query private var allFamilies: [Family]

    @State private var speciesSearchText = ""
    @State private var relatedSearchText = ""
    @State private var selectedGenus: String? = nil
    @State private var isDescriptionExpanded = false

    // MARK: - Filtered Data

    private var speciesInFamily: [Plant] {
        allPlants.filter { $0.familyLatin == family.familyLatin }
    }

    private var filteredSpecies: [Plant] {
        var result = speciesInFamily

        if let genus = selectedGenus {
            result = result.filter { $0.genus == genus }
        }

        if !speciesSearchText.isEmpty {
            result = result.filter {
                $0.scientificName.localizedCaseInsensitiveContains(speciesSearchText) ||
                $0.commonName.localizedCaseInsensitiveContains(speciesSearchText) ||
                $0.genus.localizedCaseInsensitiveContains(speciesSearchText)
            }
        }

        return result
    }

    private var speciesGenera: [String] {
        let genera = Set(speciesInFamily.map(\.genus).filter { !$0.isEmpty })
        return genera.sorted()
    }

    private var relatedFamilies: [Family] {
        allFamilies.filter { $0.order == family.order && $0.familyLatin != family.familyLatin }
    }

    private var filteredRelatedFamilies: [Family] {
        guard !relatedSearchText.isEmpty else { return relatedFamilies }
        return relatedFamilies.filter {
            $0.familyLatin.localizedCaseInsensitiveContains(relatedSearchText) ||
            $0.familyEnglish.localizedCaseInsensitiveContains(relatedSearchText)
        }
    }

    private var generaList: [String] {
        family.genera
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    taxonomyPills
                    descriptionSection
                    traitsSection
                    generaSection
                    speciesInFamilySection
                    relatedFamiliesSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            // Floating Study Button
            NavigationLink(destination: FamilyFlashcardView().navigationTitle("").navigationBarTitleDisplayMode(.inline)) {
                VStack(spacing: 3) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(AppTypography.inter(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.brandPurple)
                        .frame(width: 44, height: 44)
                        .background(AppColors.brandPurple.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.brandPurple.opacity(0.4), lineWidth: 1.5)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(family.familyLatin)
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            Text(family.familyEnglish)
                .font(AppTypography.displayMedium)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Taxonomy Pills

    private var taxonomyPills: some View {
        HStack(spacing: 12) {
            if !family.order.isEmpty {
                Text(family.order)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(Color.orangePrimary)
            }
            if !family.taxonomicClass.isEmpty {
                Text(family.taxonomicClass)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(Color.greenSecondary)
            }
            if !family.kingdom.isEmpty {
                Text(family.kingdom)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(Color.purpleSecondary)
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(markdownToAttributed(family.familyDescription))
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

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Traits")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                traitDisclosureGroup(title: "Leaf Traits", icon: "leaf.fill", traits: leafTraits)
                traitDisclosureGroup(title: "Stem Traits", icon: "laurel.leading", traits: stemTraits)
                traitDisclosureGroup(title: "Flower Traits", icon: "camera.macro", traits: flowerTraits)
                traitDisclosureGroup(title: "Fruit Traits", icon: "drop.fill", traits: fruitTraits)
                traitDisclosureGroup(title: "Root Traits", icon: "carrot.fill", traits: rootTraits)
                traitDisclosureGroup(title: "Habitat", icon: "mountain.2.fill", traits: habitatTraits)
            }
        }
    }

    private var leafTraits: [(String, String)] {
        [
            ("Type", family.leafType), ("Attachment", family.leafAttachment),
            ("Arrangement", family.leafArrangement), ("Shape", family.leafShape),
            ("Margin", family.leafMargin), ("Apex", family.leafApex),
            ("Base", family.leafBase), ("Venation", family.leafVenation),
            ("Texture", family.leafTexture), ("Stipules", family.leafStipules),
            ("Additional Trait", family.leafAdditionalTrait)
        ].compactMap { pair in guard let v = pair.1, !v.isEmpty else { return nil }; return (pair.0, v) }
    }

    private var stemTraits: [(String, String)] {
        [("Habit", family.stemHabit), ("Structure", family.stemStructure), ("Branching", family.stemBranching)]
            .compactMap { pair in guard let v = pair.1, !v.isEmpty else { return nil }; return (pair.0, v) }
    }

    private var flowerTraits: [(String, String)] {
        [
            ("Inflorescence", family.flowerInflorescence), ("Symmetry", family.flowerSymmetry),
            ("Petal Count", family.flowerPetalCount), ("Petal Fusion", family.flowerPetalFusion),
            ("Sepal Presence", family.flowerSepalPresence), ("Sepal Fusion", family.flowerSepalFusion),
            ("Color", family.flowerColor), ("Position", family.flowerPosition),
            ("Ovary Position", family.flowerOvaryPosition), ("Sexuality", family.flowerSexuality),
            ("Floral Part", family.flowerFloralPart)
        ].compactMap { pair in guard let v = pair.1, !v.isEmpty else { return nil }; return (pair.0, v) }
    }

    private var fruitTraits: [(String, String)] {
        [("Type", family.fruitType), ("Seed Trait", family.fruitSeedTrait)]
            .compactMap { pair in guard let v = pair.1, !v.isEmpty else { return nil }; return (pair.0, v) }
    }

    private var rootTraits: [(String, String)] {
        [("Type", family.rootType), ("Root Trait", family.rootTrait)]
            .compactMap { pair in guard let v = pair.1, !v.isEmpty else { return nil }; return (pair.0, v) }
    }

    private var habitatTraits: [(String, String)] {
        [("Habitat", family.habitat), ("Soil", family.soil), ("Growth Habit", family.growthHabit)]
            .compactMap { pair in guard let v = pair.1, !v.isEmpty else { return nil }; return (pair.0, v) }
    }

    @ViewBuilder
    private func traitDisclosureGroup(title: String, icon: String, traits: [(String, String)]) -> some View {
        if !traits.isEmpty {
            DisclosureGroup {
                VStack(spacing: 0) {
                    ForEach(Array(traits.enumerated()), id: \.offset) { index, trait in
                        traitRow(name: trait.0, value: trait.1)
                        if index < traits.count - 1 {
                            Divider().background(AppColors.border)
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
            .padding(16)
        }
    }

    private func traitRow(name: String, value: String) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 110, alignment: .leading)
            Spacer()
            Text(value)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Genera

    @ViewBuilder
    private var generaSection: some View {
        if !generaList.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Genera")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                WrappingHStack(items: generaList) { genus in
                    CategoryPill(text: genus, color: .greenSecondary)
                }
            }
        }
    }

    // MARK: - Species in Family (with search + genus filter)

    @ViewBuilder
    private var speciesInFamilySection: some View {
        if !speciesInFamily.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                // Header with count
                CollectionHeader(
                    icon: "leaf.fill",
                    title: "Species in this Family",
                    count: filteredSpecies.count,
                    total: speciesInFamily.count,
                    color: .greenSecondary
                )

                // Inline search
                InlineSearchField(
                    text: $speciesSearchText,
                    placeholder: "Search species..."
                )

                // Genus filter chips
                if speciesGenera.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            MiniFilterChip(name: "All", isSelected: selectedGenus == nil, color: .greenSecondary) {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedGenus = nil }
                            }
                            ForEach(speciesGenera, id: \.self) { genus in
                                MiniFilterChip(name: genus, isSelected: selectedGenus == genus, color: .greenSecondary) {
                                    withAnimation(.easeInOut(duration: 0.15)) { selectedGenus = genus }
                                }
                            }
                        }
                    }
                }

                // Results
                if filteredSpecies.isEmpty {
                    MiniEmptyState(icon: "leaf", text: "No matching species", color: .greenSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filteredSpecies, id: \.scientificName) { plant in
                                let index = filteredSpecies.firstIndex(where: { $0.id == plant.id }) ?? 0
                                NavigationLink(destination: CollectionPagerView(items: filteredSpecies, startIndex: index) { p in
                                    PlantDetailView(plant: p)
                                }) {
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
            // Thin accent line
            RoundedRectangle(cornerRadius: 1)
                .fill(AppColors.success.opacity(0.2))
                .frame(height: 1.5)

            VStack(alignment: .leading, spacing: 3) {
                Text(plant.scientificName)
                    .font(AppTypography.tagText)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .italic()
                    .lineLimit(1)

                Text(plant.titleCasedCommonName)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                Text(plant.genus)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .lineLimit(1)
                    .padding(.top, 1)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .frame(width: 155)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }

    // MARK: - Related Families (with search)

    @ViewBuilder
    private var relatedFamiliesSection: some View {
        if !relatedFamilies.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CollectionHeader(
                    icon: "leaf.circle.fill",
                    title: "Related Families",
                    count: filteredRelatedFamilies.count,
                    total: relatedFamilies.count,
                    color: .orangePrimary
                )

                // Inline search
                if relatedFamilies.count > 4 {
                    InlineSearchField(
                        text: $relatedSearchText,
                        placeholder: "Search related families..."
                    )
                }

                // Results
                if filteredRelatedFamilies.isEmpty {
                    MiniEmptyState(icon: "leaf.circle", text: "No matching families", color: .orangePrimary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filteredRelatedFamilies, id: \.familyLatin) { relatedFamily in
                                let index = filteredRelatedFamilies.firstIndex(where: { $0.id == relatedFamily.id }) ?? 0
                                NavigationLink(destination: CollectionPagerView(items: filteredRelatedFamilies, startIndex: index) { f in
                                    FamilyDetailView(family: f)
                                }) {
                                    familyCard(relatedFamily)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func familyCard(_ relatedFamily: Family) -> some View {
        let speciesCount = allPlants.filter { $0.familyLatin == relatedFamily.familyLatin }.count
        return VStack(alignment: .leading, spacing: 3) {
            Text(relatedFamily.familyLatin)
                .font(AppTypography.tagText)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
            Text(relatedFamily.familyEnglish)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
            if speciesCount > 0 {
                Text("\(speciesCount) species")
                    .font(AppTypography.inter(size: 9, weight: .medium))
                    .foregroundStyle(AppColors.primaryAmber)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.primaryAmber.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: 155)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColors.border, lineWidth: 0.5))
    }
}

// MARK: - Hashable Conformance for Family Navigation

extension Family: Hashable {
    static func == (lhs: Family, rhs: Family) -> Bool {
        lhs.familyLatin == rhs.familyLatin
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(familyLatin)
    }
}

// MARK: - Wrapping HStack for Genera Pills

struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                content(item)
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + 6
                        }
                        let result = width
                        if index == items.count - 1 {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == items.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: geometry.size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            binding.wrappedValue = height
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    NavigationStack {
        FamilyDetailView(
            family: Family(
                familyLatin: "Fagaceae",
                familyEnglish: "Beech Family",
                genera: "Quercus, Fagus, Castanea, Lithocarpus, Chrysolepis",
                order: "Fagales",
                taxonomicClass: "Magnoliopsida",
                kingdom: "Plantae",
                familyDescription: "A large family of flowering trees and shrubs known for their nut-bearing fruits and alternate, simple leaves."
            )
        )
    }
}
