import SwiftUI
import SwiftData

struct FamilyDetailView: View {
    let family: Family

    @Environment(\.modelContext) private var modelContext

    @State private var allPlants: [Plant] = []
    @State private var allFamilies: [Family] = []
    @State private var isDescriptionExpanded = false

    // MARK: - Filtered Data

    private var speciesInFamily: [Plant] {
        allPlants.filter { $0.familyLatin == family.familyLatin }
    }

    private var relatedFamilies: [Family] {
        allFamilies.filter { $0.order == family.order && $0.familyLatin != family.familyLatin }
    }

    private var generaList: [String] {
        family.genera
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Body

    var body: some View {
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
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle(family.familyLatin)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(family.familyLatin)
                .font(AppFont.title())
                .foregroundStyle(Color.textPrimary)

            Text(family.familyEnglish)
                .font(AppFont.bodyLarge())
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Taxonomy Pills

    private var taxonomyPills: some View {
        HStack(spacing: 8) {
            if !family.order.isEmpty {
                CategoryPill(text: family.order, color: .orangePrimary)
            }
            if !family.taxonomicClass.isEmpty {
                CategoryPill(text: family.taxonomicClass, color: .greenSecondary)
            }
            if !family.kingdom.isEmpty {
                CategoryPill(text: family.kingdom, color: .purpleSecondary)
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)

            Text(markdownToAttributed(family.familyDescription))
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(4)
                .lineLimit(isDescriptionExpanded ? nil : 4)

            if family.familyDescription.count > 150 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDescriptionExpanded.toggle()
                    }
                } label: {
                    Text(isDescriptionExpanded ? "Show less" : "Show more")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.orangePrimary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Traits

    private var traitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key Traits")
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
            ("Type", family.leafType),
            ("Attachment", family.leafAttachment),
            ("Arrangement", family.leafArrangement),
            ("Shape", family.leafShape),
            ("Margin", family.leafMargin),
            ("Apex", family.leafApex),
            ("Base", family.leafBase),
            ("Venation", family.leafVenation),
            ("Texture", family.leafTexture),
            ("Stipules", family.leafStipules),
            ("Additional Trait", family.leafAdditionalTrait)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var stemTraits: [(String, String)] {
        [
            ("Habit", family.stemHabit),
            ("Structure", family.stemStructure),
            ("Branching", family.stemBranching)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var flowerTraits: [(String, String)] {
        [
            ("Inflorescence", family.flowerInflorescence),
            ("Symmetry", family.flowerSymmetry),
            ("Petal Count", family.flowerPetalCount),
            ("Petal Fusion", family.flowerPetalFusion),
            ("Sepal Presence", family.flowerSepalPresence),
            ("Sepal Fusion", family.flowerSepalFusion),
            ("Color", family.flowerColor),
            ("Position", family.flowerPosition),
            ("Ovary Position", family.flowerOvaryPosition),
            ("Sexuality", family.flowerSexuality),
            ("Floral Part", family.flowerFloralPart)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var fruitTraits: [(String, String)] {
        [
            ("Type", family.fruitType),
            ("Seed Trait", family.fruitSeedTrait)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var rootTraits: [(String, String)] {
        [
            ("Type", family.rootType),
            ("Root Trait", family.rootTrait)
        ].compactMap { pair in
            guard let value = pair.1, !value.isEmpty else { return nil }
            return (pair.0, value)
        }
    }

    private var habitatTraits: [(String, String)] {
        [
            ("Habitat", family.habitat),
            ("Soil", family.soil),
            ("Growth Habit", family.growthHabit)
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
                .frame(width: 110, alignment: .leading)

            Spacer()

            Text(value)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)
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
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)

                WrappingHStack(items: generaList) { genus in
                    CategoryPill(text: genus, color: .greenSecondary)
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Species in Family

    @ViewBuilder
    private var speciesInFamilySection: some View {
        if !speciesInFamily.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Species in this Family")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(speciesInFamily, id: \.scientificName) { plant in
                            NavigationLink(value: plant) {
                                speciesCard(plant)
                            }
                        }
                    }
                }
            }
        }
    }

    private func speciesCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.surfaceElevated)
                .frame(width: 130, height: 90)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundStyle(Color.greenSecondary.opacity(0.3))
                )

            Text(plant.commonName)
                .font(AppFont.caption())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(plant.scientificName)
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
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Related Families

    @ViewBuilder
    private var relatedFamiliesSection: some View {
        if !relatedFamilies.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Related Families")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(relatedFamilies, id: \.familyLatin) { relatedFamily in
                            NavigationLink(value: relatedFamily) {
                                familyCard(relatedFamily)
                            }
                        }
                    }
                }
            }
        }
    }

    private func familyCard(_ relatedFamily: Family) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.surfaceElevated)
                .frame(width: 140, height: 80)
                .overlay(
                    Image(systemName: "tree.fill")
                        .font(.title3)
                        .foregroundStyle(Color.orangePrimary.opacity(0.3))
                )

            Text(relatedFamily.familyLatin)
                .font(AppFont.caption())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(relatedFamily.familyEnglish)
                .font(AppFont.caption(10))
                .foregroundStyle(Color.textMuted)
                .lineLimit(1)
        }
        .frame(width: 140)
        .padding(8)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 0.5)
        )
    }

    private func loadData() {
        allPlants = (try? modelContext.fetch(FetchDescriptor<Plant>())) ?? []
        allFamilies = (try? modelContext.fetch(FetchDescriptor<Family>())) ?? []
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
