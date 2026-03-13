import SwiftUI
import SwiftData

struct SpeciesGridView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]

    var filterCategory: String? = nil

    @State private var searchText = ""
    @State private var selectedFamily: String? = nil
    @State private var selectedGenus: String? = nil
    @State private var selectedCommonName: String? = nil

    // MARK: - Cached Filter Results (avoid recomputing on every render)
    @State private var cachedCategoryPlants: [Plant] = []
    @State private var cachedFilteredPlants: [Plant] = []
    @State private var cachedFamilies: [(name: String, count: Int)] = []
    @State private var cachedGenera: [(name: String, count: Int)] = []
    @State private var cachedCommonNames: [(name: String, count: Int)] = []

    private let columns = [
        GridItem(.flexible())
    ]

    private var hasActiveFilters: Bool {
        selectedFamily != nil || selectedGenus != nil || selectedCommonName != nil || !searchText.isEmpty
    }

    // MARK: - Recompute Helpers

    private func recomputeAll() {
        cachedCategoryPlants = computeCategoryFiltered()
        cachedFamilies = computeFamilies(from: cachedCategoryPlants)
        cachedGenera = computeGenera(from: cachedCategoryPlants, family: selectedFamily)
        cachedCommonNames = computeCommonNames(from: cachedCategoryPlants, family: selectedFamily, genus: selectedGenus)
        cachedFilteredPlants = computeFiltered(from: cachedCategoryPlants)
    }

    private func computeCategoryFiltered() -> [Plant] {
        guard let category = filterCategory else { return allPlants }
        switch category {
        case "Flowers":
            return allPlants.filter { $0.flowerColor != nil && !($0.flowerColor?.isEmpty ?? true) }
        case "Leaves":
            return allPlants.filter { $0.leafType != nil && !($0.leafType?.isEmpty ?? true) }
        case "Fruits":
            return allPlants.filter { $0.fruitType != nil && !($0.fruitType?.isEmpty ?? true) }
        case "Bark":
            return allPlants.filter {
                ($0.stemStructure != nil && !($0.stemStructure?.isEmpty ?? true)) ||
                ($0.stemHabit != nil && !($0.stemHabit?.isEmpty ?? true))
            }
        case "Stems":
            return allPlants.filter { $0.stemStructure != nil && !($0.stemStructure?.isEmpty ?? true) }
        case "Roots":
            return allPlants.filter { $0.rootType != nil && !($0.rootType?.isEmpty ?? true) }
        default:
            return allPlants
        }
    }

    private func computeFamilies(from base: [Plant]) -> [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: base.filter { !$0.familyLatin.isEmpty }) { $0.familyLatin }
        return grouped.map { (name: $0.key, count: $0.value.count) }.sorted { $0.name < $1.name }
    }

    private func computeGenera(from base: [Plant], family: String?) -> [(name: String, count: Int)] {
        var plants = base
        if let family { plants = plants.filter { $0.familyLatin == family } }
        let grouped = Dictionary(grouping: plants.filter { !$0.genus.isEmpty }) { $0.genus }
        return grouped.map { (name: $0.key, count: $0.value.count) }.sorted { $0.name < $1.name }
    }

    private func computeCommonNames(from base: [Plant], family: String?, genus: String?) -> [(name: String, count: Int)] {
        var plants = base
        if let family { plants = plants.filter { $0.familyLatin == family } }
        if let genus { plants = plants.filter { $0.genus == genus } }
        let grouped = Dictionary(grouping: plants.filter { !$0.commonName.isEmpty }) { $0.commonName }
        return grouped.map { (name: $0.key, count: $0.value.count) }.sorted { $0.name < $1.name }
    }

    private func computeFiltered(from base: [Plant]) -> [Plant] {
        var result = base
        if let family = selectedFamily { result = result.filter { $0.familyLatin == family } }
        if let genus = selectedGenus { result = result.filter { $0.genus == genus } }
        if let commonName = selectedCommonName { result = result.filter { $0.commonName == commonName } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.scientificName.localizedCaseInsensitiveContains(searchText) ||
                $0.commonName.localizedCaseInsensitiveContains(searchText) ||
                $0.familyLatin.localizedCaseInsensitiveContains(searchText) ||
                $0.genus.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterDropdownBar
            resultCountBar

            if cachedFilteredPlants.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(cachedFilteredPlants) { plant in
                            plantCell(plant)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.species)
        .onAppear { if cachedCategoryPlants.isEmpty { recomputeAll() } }
        .onChange(of: allPlants.count) { _, _ in recomputeAll() }
        .onChange(of: searchText) { _, _ in
            cachedFilteredPlants = computeFiltered(from: cachedCategoryPlants)
        }
        .onChange(of: selectedFamily) { _, _ in
            // Recompute dependent filters
            cachedGenera = computeGenera(from: cachedCategoryPlants, family: selectedFamily)
            cachedCommonNames = computeCommonNames(from: cachedCategoryPlants, family: selectedFamily, genus: selectedGenus)
            cachedFilteredPlants = computeFiltered(from: cachedCategoryPlants)
            // Reset genus if no longer valid for new family
            if let genus = selectedGenus,
               !cachedGenera.contains(where: { $0.name == genus }) {
                selectedGenus = nil
            }
            // Reset common name if no longer valid
            if let common = selectedCommonName,
               !cachedCommonNames.contains(where: { $0.name == common }) {
                selectedCommonName = nil
            }
        }
        .onChange(of: selectedGenus) { _, _ in
            cachedCommonNames = computeCommonNames(from: cachedCategoryPlants, family: selectedFamily, genus: selectedGenus)
            cachedFilteredPlants = computeFiltered(from: cachedCategoryPlants)
            // Reset common name if no longer valid for new genus
            if let common = selectedCommonName,
               !cachedCommonNames.contains(where: { $0.name == common }) {
                selectedCommonName = nil
            }
        }
        .onChange(of: selectedCommonName) { _, _ in
            cachedFilteredPlants = computeFiltered(from: cachedCategoryPlants)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.textMuted)

            TextField("Search species, families, genera...", text: $searchText)
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

    // MARK: - Filter Dropdown Bar

    private var filterDropdownBar: some View {
        HStack(spacing: 8) {
            // Family dropdown
            Menu {
                Button {
                    selectedFamily = nil
                } label: {
                    HStack {
                        Text("All Families")
                        if selectedFamily == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(cachedFamilies, id: \.name) { family in
                    Button {
                        selectedFamily = family.name
                    } label: {
                        HStack {
                            Text("\(family.name) (\(family.count))")
                            if selectedFamily == family.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                filterMenuLabel(
                    title: selectedFamily ?? "Family",
                    isActive: selectedFamily != nil,
                    color: .orangePrimary
                )
            }

            // Genus dropdown
            Menu {
                Button {
                    selectedGenus = nil
                } label: {
                    HStack {
                        Text("All Genera")
                        if selectedGenus == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(cachedGenera, id: \.name) { genus in
                    Button {
                        selectedGenus = genus.name
                    } label: {
                        HStack {
                            Text("\(genus.name) (\(genus.count))")
                            if selectedGenus == genus.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                filterMenuLabel(
                    title: selectedGenus ?? "Genus",
                    isActive: selectedGenus != nil,
                    color: .orangePrimary
                )
            }

            // Common Name dropdown
            Menu {
                Button {
                    selectedCommonName = nil
                } label: {
                    HStack {
                        Text("All Common Names")
                        if selectedCommonName == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(cachedCommonNames, id: \.name) { common in
                    Button {
                        selectedCommonName = common.name
                    } label: {
                        HStack {
                            Text(common.name)
                            if selectedCommonName == common.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                filterMenuLabel(
                    title: selectedCommonName ?? "Common",
                    isActive: selectedCommonName != nil,
                    color: .orangePrimary
                )
            }

            if selectedFamily != nil || selectedGenus != nil || selectedCommonName != nil {
                Button {
                    selectedFamily = nil
                    selectedGenus = nil
                    selectedCommonName = nil
                } label: {
                    Text("Clear")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.success)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func filterMenuLabel(title: String, isActive: Bool, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(AppTypography.tagText)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(AppTypography.inter(size: 9, weight: .semibold))
        }
        .foregroundStyle(isActive ? .white : AppColors.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isActive ? color : AppColors.cardElevated)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isActive ? color : AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Result Count Bar

    private var resultCountBar: some View {
        HStack(spacing: 4) {
            let count = cachedFilteredPlants.count
            let total = cachedCategoryPlants.count

            Text("\(count) of \(total) species")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)

            if let family = selectedFamily {
                if let genus = selectedGenus {
                    Text("in \(family) › \(genus)")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.success)
                } else {
                    Text("in \(family)")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.success)
                }
            } else if let genus = selectedGenus {
                Text("in \(genus)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.success)
            }

            if let commonName = selectedCommonName {
                Text("· \(commonName)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.success)
            }

            if hasActiveFilters {
                Text("·")
                    .foregroundStyle(AppColors.textMuted)
                Button {
                    selectedFamily = nil
                    selectedGenus = nil
                    selectedCommonName = nil
                    searchText = ""
                } label: {
                    Text("Clear")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.success)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "leaf.circle")
                .font(AppTypography.inter(size: 40))
                .foregroundStyle(AppColors.textMuted.opacity(0.5))

            Text("No species found")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)

            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            if hasActiveFilters {
                Button {
                    searchText = ""
                    selectedFamily = nil
                    selectedGenus = nil
                    selectedCommonName = nil
                } label: {
                    Text("Clear all filters")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.success)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.success.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let category = filterCategory {
            return category
        }
        return "Species"
    }

    // MARK: - Plant Cell

    private func plantCell(_ plant: Plant) -> some View {
        let index = cachedFilteredPlants.firstIndex(where: { $0.id == plant.id }) ?? 0
        return NavigationLink(destination: CollectionPagerView(items: cachedFilteredPlants, startIndex: index) { p in
            PlantDetailView(plant: p)
        }) {
            plantCellContent(plant: plant)
        }
        .buttonStyle(GridCellButtonStyle())
    }

    private func plantCellContent(plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Common name
            Text(plant.titleCasedCommonName)
                .font(AppTypography.bodyText)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            // Scientific name (italic)
            Text(plant.scientificName)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)

            // Family + at-risk badge
            HStack(spacing: 0) {
                Text(plant.familyLatin)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if plant.isAtRisk, let status = plant.atRiskStatus {
                    Text(status.contains("Critically") ? "CR" : status.contains("Endangered") ? "EN" : "AR")
                        .font(AppTypography.inter(size: 8, weight: .bold))
                        .foregroundStyle(status.contains("Critically") || status.contains("Endangered") ? AppColors.error : AppColors.warning)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((status.contains("Critically") || status.contains("Endangered") ? AppColors.error : AppColors.warning).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Grid Cell Press Style

private struct GridCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        SpeciesGridView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: Plant.self, inMemory: true)
    .preferredColorScheme(.dark)
}
