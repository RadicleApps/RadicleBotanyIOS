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
    @State private var fetchedImageURLs: [String: String] = [:]  // scientificName → imageURL

    private let columns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5)
    ]

    // MARK: - Computed Properties

    private var filteredSpecies: [UPSSpecies] {
        if let cat = selectedCategory {
            return UPSSpecies.all.filter { $0.category == cat }
        }
        return UPSSpecies.all
    }

    private func matchedPlant(for species: UPSSpecies) -> Plant? {
        let searchName = species.scientificName.lowercased()
        // Exact match first
        if let exact = allPlants.first(where: { $0.scientificName.lowercased() == searchName }) {
            return exact
        }
        // For "spp." entries, match by genus
        if searchName.hasSuffix("spp.") {
            let genus = searchName.replacingOccurrences(of: " spp.", with: "")
            return allPlants.first(where: { $0.genus.lowercased() == genus })
        }
        return nil
    }

    private var inDatabaseCount: Int {
        UPSSpecies.all.filter { matchedPlant(for: $0) != nil }.count
    }

    /// Best image URL for a species: database plant first, then fetched cache
    private func imageURL(for species: UPSSpecies) -> URL? {
        // Priority 1: matched database plant with populated image
        if let plant = matchedPlant(for: species), let urlStr = plant.bestImageURL, let url = URL(string: urlStr) {
            return url
        }
        // Priority 2: directly fetched from iNaturalist/Wikipedia
        if let urlStr = fetchedImageURLs[species.scientificName], let url = URL(string: urlStr) {
            return url
        }
        return nil
    }

    /// Fetch images for all UPS species via PlantImageService
    private func fetchAllSpeciesImages() async {
        let service = PlantImageService.shared
        await withTaskGroup(of: (String, String?).self) { group in
            for species in UPSSpecies.all {
                group.addTask {
                    // For "spp." entries, search by genus name (more likely to get results)
                    let searchName = species.scientificName.hasSuffix("spp.")
                        ? species.scientificName.replacingOccurrences(of: " spp.", with: "")
                        : species.scientificName
                    let url = await service.fetchImageURL(for: searchName)
                    return (species.scientificName, url)
                }
            }
            for await (name, url) in group {
                if let url {
                    fetchedImageURLs[name] = url
                }
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                    .padding(.horizontal, 16)
                upsEducationSection
                    .padding(.horizontal, 16)
                categoryFilterBar
                    .padding(.horizontal, 16)
                speciesGrid
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(AppColors.appBackground)
        .navigationTitle("At-Risk Plants")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                InfoButton(guide: .conservation, style: .toolbar)
            }
        }
        .task {
            if fetchedImageURLs.isEmpty {
                await fetchAllSpeciesImages()
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

            // In-database stat
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(AppTypography.inter(size: 10))
                    .foregroundStyle(AppColors.success)
                Text("\(inDatabaseCount) of \(UPSSpecies.all.count) species in your database")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
                Spacer()
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

    private var speciesGrid: some View {
        LazyVGrid(columns: columns, spacing: 1.5) {
            ForEach(filteredSpecies) { species in
                speciesCell(species)
            }
        }
    }

    // MARK: - Species Cell

    private func speciesCell(_ species: UPSSpecies) -> some View {
        let plant = matchedPlant(for: species)

        return Group {
            if let plant {
                NavigationLink(destination: PlantDetailView(plant: plant)) {
                    speciesCellContent(species: species, plant: plant)
                }
            } else {
                NavigationLink(destination: UPSSpeciesDetailView(species: species, imageURL: imageURL(for: species))) {
                    speciesCellContent(species: species, plant: nil)
                }
            }
        }
        .buttonStyle(ConservationCellButtonStyle())
    }

    private func speciesCellContent(species: UPSSpecies, plant: Plant?) -> some View {
        let isInDatabase = plant != nil

        return GeometryReader { geo in
            ZStack {
                // Square image — cached first, then URL, then placeholder
                ZStack(alignment: .bottom) {
                    if let plant = plant, let cachedImage = plant.cachedImage {
                        // Priority 1: Persistent cached image from matched database plant
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                    } else if let url = imageURL(for: species) {
                        // Priority 2: URL-based image (database plant URL or fetched URL)
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.width)
                                    .clipped()
                            default:
                                gridCellPlaceholder(size: geo.size.width, species: species)
                            }
                        }
                    } else {
                        gridCellPlaceholder(size: geo.size.width, species: species)
                    }

                    // Bottom label overlay
                    VStack(spacing: 2) {
                        Text(species.commonName)
                            .font(AppTypography.tagText)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(species.scientificName)
                            .font(.system(size: 10, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)

                        Text(species.category.rawValue.uppercased())
                            .font(AppTypography.inter(size: 8, weight: .bold))
                            .foregroundStyle(species.category.color)
                            .padding(.top, 1)
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
                }

                // Top-right badge: database match indicator
                if isInDatabase {
                    // Green checkmark = tappable, opens detail
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppTypography.inter(size: 16))
                                .foregroundStyle(AppColors.success)
                                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
    }

    private func gridCellPlaceholder(size: CGFloat, species: UPSSpecies) -> some View {
        AppColors.cardElevated
            .frame(width: size, height: size)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: species.category.icon)
                        .font(AppTypography.inter(size: 28))
                        .foregroundStyle(species.category.color.opacity(0.3))

                    Text(species.commonName)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
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
