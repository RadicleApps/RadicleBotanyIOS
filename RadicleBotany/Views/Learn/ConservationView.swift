import SwiftUI
import SwiftData

// MARK: - UPS Data Model

enum UPSCategory: String, CaseIterable, Identifiable {
    case critical = "Critical"
    case atRisk = "At-Risk"
    case toWatch = "To-Watch"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .critical: return .errorRed
        case .atRisk: return .warningAmber
        case .toWatch: return .purpleSecondary
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .atRisk: return "exclamationmark.circle.fill"
        case .toWatch: return "eye.fill"
        }
    }

    var description: String {
        switch self {
        case .critical:
            return "Species at very high risk of extinction. Never wildharvest these plants."
        case .atRisk:
            return "Under significant pressure from overharvesting, habitat loss, and climate change."
        case .toWatch:
            return "Being monitored for potential At-Risk classification due to growing concerns."
        }
    }
}

struct UPSSpecies: Identifiable {
    let id = UUID()
    let commonName: String
    let scientificName: String
    let category: UPSCategory

    static let all: [UPSSpecies] = critical + atRisk + toWatch

    static let critical: [UPSSpecies] = [
        UPSSpecies(commonName: "False Unicorn", scientificName: "Chamaelirium luteum", category: .critical),
        UPSSpecies(commonName: "Lady's Slipper Orchid", scientificName: "Cypripedium spp.", category: .critical),
        UPSSpecies(commonName: "Peyote", scientificName: "Lophophora williamsii", category: .critical),
        UPSSpecies(commonName: "Sandalwood", scientificName: "Santalum spp.", category: .critical),
        UPSSpecies(commonName: "Sundew", scientificName: "Drosera spp.", category: .critical),
        UPSSpecies(commonName: "Trillium", scientificName: "Trillium spp.", category: .critical),
        UPSSpecies(commonName: "True Unicorn", scientificName: "Aletris farinosa", category: .critical),
        UPSSpecies(commonName: "Venus Fly Trap", scientificName: "Dionaea muscipula", category: .critical),
    ]

    static let atRisk: [UPSSpecies] = [
        UPSSpecies(commonName: "American Ginseng", scientificName: "Panax quinquefolius", category: .atRisk),
        UPSSpecies(commonName: "Black Cohosh", scientificName: "Actaea racemosa", category: .atRisk),
        UPSSpecies(commonName: "Bloodroot", scientificName: "Sanguinaria canadensis", category: .atRisk),
        UPSSpecies(commonName: "Blue Cohosh", scientificName: "Caulophyllum thalictroides", category: .atRisk),
        UPSSpecies(commonName: "Butterfly Weed", scientificName: "Asclepias tuberosa", category: .atRisk),
        UPSSpecies(commonName: "Cascara Sagrada", scientificName: "Frangula purshiana", category: .atRisk),
        UPSSpecies(commonName: "Chaparro", scientificName: "Castela emoryi", category: .atRisk),
        UPSSpecies(commonName: "Echinacea", scientificName: "Echinacea spp.", category: .atRisk),
        UPSSpecies(commonName: "Gentian", scientificName: "Gentiana spp.", category: .atRisk),
        UPSSpecies(commonName: "Ghost Pipe", scientificName: "Monotropa uniflora", category: .atRisk),
        UPSSpecies(commonName: "Goldenseal", scientificName: "Hydrastis canadensis", category: .atRisk),
        UPSSpecies(commonName: "Goldthread", scientificName: "Coptis spp.", category: .atRisk),
        UPSSpecies(commonName: "Kava", scientificName: "Piper methysticum", category: .atRisk),
        UPSSpecies(commonName: "Lomatium", scientificName: "Lomatium dissectum", category: .atRisk),
        UPSSpecies(commonName: "Maidenhair Fern", scientificName: "Adiantum pedatum", category: .atRisk),
        UPSSpecies(commonName: "Mayapple", scientificName: "Podophyllum peltatum", category: .atRisk),
        UPSSpecies(commonName: "Oregon Grape", scientificName: "Mahonia spp.", category: .atRisk),
        UPSSpecies(commonName: "Osha", scientificName: "Ligusticum porteri", category: .atRisk),
        UPSSpecies(commonName: "Slippery Elm", scientificName: "Ulmus rubra", category: .atRisk),
        UPSSpecies(commonName: "Virginia Snakeroot", scientificName: "Aristolochia serpentaria", category: .atRisk),
        UPSSpecies(commonName: "Wild Yam", scientificName: "Dioscorea villosa", category: .atRisk),
    ]

    static let toWatch: [UPSSpecies] = [
        UPSSpecies(commonName: "Arnica", scientificName: "Arnica spp.", category: .toWatch),
        UPSSpecies(commonName: "Calamus", scientificName: "Acorus calamus", category: .toWatch),
        UPSSpecies(commonName: "Eyebright", scientificName: "Euphrasia spp.", category: .toWatch),
        UPSSpecies(commonName: "Lobelia", scientificName: "Lobelia spp.", category: .toWatch),
        UPSSpecies(commonName: "Partridge Berry", scientificName: "Mitchella repens", category: .toWatch),
        UPSSpecies(commonName: "Pipsissewa", scientificName: "Chimaphila umbellata", category: .toWatch),
        UPSSpecies(commonName: "Spikenard", scientificName: "Aralia racemosa", category: .toWatch),
        UPSSpecies(commonName: "White Sage", scientificName: "Salvia apiana", category: .toWatch),
        UPSSpecies(commonName: "Wild Indigo", scientificName: "Baptisia tinctoria", category: .toWatch),
    ]
}

// MARK: - Conservation View

struct ConservationView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]

    @State private var selectedCategory: UPSCategory? = nil
    @State private var showUPSInfo = false

    private let columns = [
        GridItem(.flexible())
    ]

    // MARK: - Computed Properties

    private var filteredSpecies: [UPSSpecies] {
        if let cat = selectedCategory {
            return UPSSpecies.all.filter { $0.category == cat }
        }
        return UPSSpecies.all
    }

    /// Build O(1) lookup from UPS species name → matched Plant.
    /// Replaces O(n) linear scan per species with single O(n) dictionary build.
    private static func buildPlantLookup(from plants: [Plant]) -> [String: Plant] {
        let byName = Dictionary(
            plants.map { ($0.scientificName.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var byGenus: [String: Plant] = [:]
        for plant in plants {
            let g = plant.genus.lowercased()
            if byGenus[g] == nil { byGenus[g] = plant }
        }

        var lookup: [String: Plant] = [:]
        for species in UPSSpecies.all {
            let name = species.scientificName.lowercased()
            if let exact = byName[name] {
                lookup[species.scientificName] = exact
            } else if name.hasSuffix("spp.") {
                let genus = name.replacingOccurrences(of: " spp.", with: "")
                if let match = byGenus[genus] {
                    lookup[species.scientificName] = match
                }
            }
        }
        return lookup
    }


    // MARK: - Body

    var body: some View {
        // Build O(1) plant lookup once per render (replaces ~140K string comparisons with ~2K)
        let lookup = Self.buildPlantLookup(from: allPlants)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                    .padding(.horizontal, 16)
                upsEducationSection
                    .padding(.horizontal, 16)
                categoryFilterBar
                    .padding(.horizontal, 16)
                speciesGrid(lookup: lookup)
            }
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                InfoButton(guide: .conservation, style: .toolbar)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "leaf.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text("United Plant Savers")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Species at risk from overharvesting & habitat loss")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                }

                Spacer()
            }

            // Category breakdown bars
            VStack(spacing: 8) {
                ForEach(UPSCategory.allCases) { cat in
                    let count: Int = {
                        switch cat {
                        case .critical: return UPSSpecies.critical.count
                        case .atRisk: return UPSSpecies.atRisk.count
                        case .toWatch: return UPSSpecies.toWatch.count
                        }
                    }()

                    HStack(spacing: 8) {
                        Image(systemName: cat.icon)
                            .font(AppTypography.inter(size: 10))
                            .foregroundStyle(cat.color)
                            .frame(width: 14)

                        Text(cat.rawValue)
                            .font(AppTypography.tagText)
                            .foregroundStyle(cat.color)
                            .frame(width: 60, alignment: .leading)

                        GeometryReader { geo in
                            let total = UPSSpecies.all.count
                            let fraction = total > 0 ? CGFloat(count) / CGFloat(total) : 0

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColors.cardElevated)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cat.color)
                                    .frame(width: max(geo.size.width * fraction, 4), height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text("\(count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(AppSpacing.sectionPadding)
    }

    // MARK: - UPS Education Section

    private var upsEducationSection: some View {
        DisclosureGroup(isExpanded: $showUPSInfo) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(UPSCategory.allCases) { cat in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: cat.icon)
                            .font(AppTypography.inter(size: 12))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 22)
                            .background(cat.color)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.rawValue)
                                .font(AppTypography.bodyText)
                                .foregroundStyle(AppColors.textPrimary)

                            Text(cat.description)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }

                Divider()
                    .overlay(AppColors.border)

                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(AppTypography.inter(size: 11))
                    Text("unitedplantsavers.org")
                        .font(AppTypography.caption)
                }
                .foregroundStyle(AppColors.success)
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(AppColors.brandPurple)

                Text("What is United Plant Savers?")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .tint(AppColors.textMuted)
        .padding(AppSpacing.sectionPadding)
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(
                    name: "All",
                    count: UPSSpecies.all.count,
                    color: .orangePrimary,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
                }

                ForEach(UPSCategory.allCases) { cat in
                    let count: Int = {
                        switch cat {
                        case .critical: return UPSSpecies.critical.count
                        case .atRisk: return UPSSpecies.atRisk.count
                        case .toWatch: return UPSSpecies.toWatch.count
                        }
                    }()

                    filterChip(
                        name: cat.rawValue,
                        count: count,
                        color: cat.color,
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
                    }
                }
            }
        }
    }

    private func filterChip(name: String, count: Int, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name)
                    .font(AppTypography.tagText)

                Text("\(count)")
                    .font(AppTypography.caption)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.2) : color.opacity(0.15))
                    .clipShape(Capsule())
            }
            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? color : AppColors.cardElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Species Grid

    private func speciesGrid(lookup: [String: Plant]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(filteredSpecies) { species in
                speciesCell(species, plant: lookup[species.scientificName])
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Species Cell

    /// All database-matched plants from the filtered species list, for pager navigation.
    private var matchedConservationPlants: [Plant] {
        filteredSpecies.compactMap { species in
            allPlants.first { $0.scientificName.lowercased() == species.scientificName.lowercased() }
        }
    }

    private func speciesCell(_ species: UPSSpecies, plant: Plant?) -> some View {
        Group {
            if let plant {
                let matched = matchedConservationPlants
                let index = matched.firstIndex(where: { $0.id == plant.id }) ?? 0
                NavigationLink(destination: CollectionPagerView(items: matched, startIndex: index) { p in
                    PlantDetailView(plant: p)
                }) {
                    speciesCellContent(species: species)
                }
            } else {
                NavigationLink(destination: UPSSpeciesDetailView(species: species, imageURL: nil)) {
                    speciesCellContent(species: species)
                }
            }
        }
        .buttonStyle(ConservationCellButtonStyle())
    }

    private func speciesCellContent(species: UPSSpecies) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Category badge
            HStack(spacing: 4) {
                Image(systemName: species.category.icon)
                    .font(AppTypography.inter(size: 9))
                Text(species.category.rawValue.uppercased())
                    .font(AppTypography.inter(size: 8, weight: .bold))
            }
            .foregroundStyle(species.category.color)

            // Common name
            Text(species.commonName.titleCased)
                .font(AppTypography.bodyText)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            // Scientific name
            Text(species.scientificName)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(species.category.color.opacity(0.3), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Grid Cell Press Style

private struct ConservationCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        ConservationView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self], inMemory: true)
    .preferredColorScheme(.dark)
}
