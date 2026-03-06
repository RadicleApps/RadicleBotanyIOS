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

    private let columns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5)
    ]

    // MARK: - Computed Properties

    private var allFamilies: [(name: String, count: Int)] {
        let basePlants = categoryFilteredPlants
        let grouped = Dictionary(grouping: basePlants.filter { !$0.familyLatin.isEmpty }) { $0.familyLatin }
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    private var allGenera: [(name: String, count: Int)] {
        // Contextual: if family selected, only genera within that family
        var basePlants = categoryFilteredPlants
        if let family = selectedFamily {
            basePlants = basePlants.filter { $0.familyLatin == family }
        }
        let grouped = Dictionary(grouping: basePlants.filter { !$0.genus.isEmpty }) { $0.genus }
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    private var allCommonNames: [(name: String, count: Int)] {
        // Contextual: respects family and genus filters
        var basePlants = categoryFilteredPlants
        if let family = selectedFamily {
            basePlants = basePlants.filter { $0.familyLatin == family }
        }
        if let genus = selectedGenus {
            basePlants = basePlants.filter { $0.genus == genus }
        }
        let grouped = Dictionary(grouping: basePlants.filter { !$0.commonName.isEmpty }) { $0.commonName }
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    /// Plants filtered only by parent category (before family/search filters).
    private var categoryFilteredPlants: [Plant] {
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

    private var filteredPlants: [Plant] {
        var result = categoryFilteredPlants

        // Apply family filter
        if let family = selectedFamily {
            result = result.filter { $0.familyLatin == family }
        }

        // Apply genus filter
        if let genus = selectedGenus {
            result = result.filter { $0.genus == genus }
        }

        // Apply common name filter
        if let commonName = selectedCommonName {
            result = result.filter { $0.commonName == commonName }
        }

        // Apply search filter
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

    private var hasActiveFilters: Bool {
        selectedFamily != nil || selectedGenus != nil || selectedCommonName != nil || !searchText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterDropdownBar
            resultCountBar

            if filteredPlants.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 1.5) {
                        ForEach(filteredPlants) { plant in
                            plantCell(plant)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.species)
        .onChange(of: selectedFamily) { _, _ in
            // Reset genus if no longer valid for new family
            if let genus = selectedGenus,
               !allGenera.contains(where: { $0.name == genus }) {
                selectedGenus = nil
            }
            // Reset common name if no longer valid
            if let common = selectedCommonName,
               !allCommonNames.contains(where: { $0.name == common }) {
                selectedCommonName = nil
            }
        }
        .onChange(of: selectedGenus) { _, _ in
            // Reset common name if no longer valid for new genus
            if let common = selectedCommonName,
               !allCommonNames.contains(where: { $0.name == common }) {
                selectedCommonName = nil
            }
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

                ForEach(allFamilies, id: \.name) { family in
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

                ForEach(allGenera, id: \.name) { genus in
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

                ForEach(allCommonNames, id: \.name) { common in
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
            let count = filteredPlants.count
            let total = categoryFilteredPlants.count

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

            Image("Ipomoea purpurea")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .opacity(0.5)

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
        NavigationLink(destination: PlantDetailView(plant: plant)) {
            plantCellContent(plant: plant, isLocked: false)
        }
        .buttonStyle(GridCellButtonStyle())
    }

    private func plantCellContent(plant: Plant, isLocked: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Square image — cached first, then URL fallback
                CachedPlantGridImage(plant: plant, size: geo.size.width)

                // Bottom label overlay
                VStack(spacing: 2) {
                    Text(plant.commonName)
                        .font(AppTypography.tagText)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(plant.scientificName)
                        .font(.system(size: 10, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    if plant.isAtRisk, let status = plant.atRiskStatus {
                        Text(status.uppercased())
                            .font(AppTypography.inter(size: 8, weight: .bold))
                            .foregroundStyle(status.contains("Critically") || status.contains("Endangered") ? AppColors.error : AppColors.warning)
                            .padding(.top, 1)
                    }
                }
                .frame(width: geo.size.width, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Lock overlay
                if isLocked {
                    Color.black.opacity(0.55)
                        .frame(width: geo.size.width, height: geo.size.width)
                    Image(systemName: "lock.fill")
                        .font(AppTypography.inter(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
    }

    /// Placeholder for grid cells when no image is available
    private func gridCellPlaceholder(size: CGFloat) -> some View {
        AppColors.cardElevated
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "leaf.fill")
                    .font(AppTypography.inter(size: 28))
                    .foregroundStyle(AppColors.success.opacity(0.2))
            }
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
