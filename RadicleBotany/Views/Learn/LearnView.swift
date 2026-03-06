import SwiftUI
import SwiftData

struct LearnView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var plants: [Plant]
    @Query(sort: \Family.familyLatin) private var families: [Family]
    @Query(sort: \BotanyTerm.term) private var terms: [BotanyTerm]

    private let categoryColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let discoverColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    // MARK: - Category Data

    private struct CategoryInfo {
        let title: String
        let icon: String
        let isAssetIcon: Bool
        let color: Color
        let subtitle: String

        init(title: String, icon: String, isAssetIcon: Bool = false, color: Color, subtitle: String) {
            self.title = title
            self.icon = icon
            self.isAssetIcon = isAssetIcon
            self.color = color
            self.subtitle = subtitle
        }
    }

    private var categoryData: [CategoryInfo] {
        [
            CategoryInfo(
                title: "Flowers",
                icon: "ph-flower-tulip",
                isAssetIcon: true,
                color: .orangePrimary,
                subtitle: "Color, symmetry & form"
            ),
            CategoryInfo(
                title: "Leaves",
                icon: "ph-leaf",
                isAssetIcon: true,
                color: .orangePrimary,
                subtitle: "Shape, margin & venation"
            ),
            CategoryInfo(
                title: "Fruits",
                icon: "ph-cherries",
                isAssetIcon: true,
                color: .orangePrimary,
                subtitle: "Seed types & dispersal"
            ),
            CategoryInfo(
                title: "Bark",
                icon: "ph-tree",
                isAssetIcon: true,
                color: .orangePrimary,
                subtitle: "Texture & growth habit"
            ),
            CategoryInfo(
                title: "Stems",
                icon: "ph-plant",
                isAssetIcon: true,
                color: .orangePrimary,
                subtitle: "Structure & branching"
            ),
            CategoryInfo(
                title: "Roots",
                icon: "carrot.fill",
                color: .orangePrimary,
                subtitle: "Root systems & types"
            )
        ]
    }

    // MARK: - Featured Species

    private var featuredSpecies: [Plant] {
        let freePlants = plants.filter { $0.isFree }
        guard !freePlants.isEmpty else { return [] }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let shuffled = freePlants.sorted { a, b in
            let hashA = abs(a.scientificName.hashValue &+ dayOfYear)
            let hashB = abs(b.scientificName.hashValue &+ dayOfYear)
            return hashA < hashB
        }
        return Array(shuffled.prefix(6))
    }

    // MARK: - Stats

    private var uniqueFamilyCount: Int {
        Set(plants.map { $0.familyLatin }).count
    }

    private var uniqueOrderCount: Int {
        Set(families.map { $0.order }.filter { !$0.isEmpty }).count
    }

    private var uniqueTermCategories: Int {
        Set(terms.map { $0.category }).count
    }

    private var bloomingNowCount: Int {
        let currentMonth = Calendar.current.component(.month, from: Date())
        return plants.filter { $0.bloomMonthArray.contains(currentMonth) }.count
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Section 1: Seasonal Spotlight Strip
                seasonalSpotlightStrip

                // Section 2: Browse by Category
                categoriesSection
                    .padding(.top, 24)

                // Section 3: Featured Species
                featuredSpeciesSection
                    .padding(.top, 24)

                // Section 4: Library
                librarySection
                    .padding(.top, 24)

                // Section 5: Discover
                discoverSection
                    .padding(.top, 24)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(AppColors.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Section 1: Seasonal Spotlight Strip

    private var seasonalSpotlightStrip: some View {
        HStack(spacing: 16) {
            NavigationLink(destination: BloomCalendarView()) {
                spotlightCircle(icon: "camera.macro", color: AppColors.primaryAmber)
            }
            .buttonStyle(SpotlightCardButtonStyle())

            NavigationLink(destination: PlantsNearMeView()) {
                spotlightCircle(icon: "location.fill", color: AppColors.primaryAmber)
            }
            .buttonStyle(SpotlightCardButtonStyle())

            NavigationLink(destination: FlashcardHubView()) {
                spotlightCircle(icon: "rectangle.on.rectangle.angled", color: AppColors.primaryAmber)
            }
            .buttonStyle(SpotlightCardButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private func spotlightCircle(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(AppTypography.inter(size: 18))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.12))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 1.5)
            )
    }

    // MARK: - Section 2: Categories

    private var categoriesSection: some View {
        LazyVGrid(columns: categoryColumns, spacing: 10) {
                ForEach(categoryData, id: \.title) { info in
                    NavigationLink(destination: CategoryDetailView(category: info.title, accentColor: info.color)) {
                        compactCategoryCard(info: info)
                    }
                    .buttonStyle(SpotlightCardButtonStyle())
                }
            }
    }

    private func compactCategoryCard(info: CategoryInfo) -> some View {
        HStack(spacing: 10) {
            Group {
                if info.isAssetIcon {
                    Image(info.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: info.icon)
                        .font(AppTypography.inter(size: 18))
                }
            }
            .foregroundStyle(info.color)
            .frame(width: 22)

            Text(info.title)
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(
            LinearGradient(
                colors: [info.color.opacity(0.15), info.color.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    // MARK: - Section 3: Featured Species

    private var featuredSpeciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Featured Plants")
                Spacer()
                Image(systemName: "sparkles")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.primaryAmber.opacity(0.6))
            }

            if featuredSpecies.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: AppRadius.button)
                                    .fill(AppColors.cardElevated)
                                    .frame(width: 150, height: 100)

                                VStack(alignment: .leading, spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppColors.cardElevated)
                                        .frame(width: 100, height: 12)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(AppColors.cardElevated.opacity(0.6))
                                        .frame(width: 70, height: 10)
                                }
                            }
                            .frame(width: 150)
                            .padding(.bottom, 4)
                        }
                    }
                }
                .redacted(reason: .placeholder)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(featuredSpecies) { plant in
                            NavigationLink(value: plant) {
                                featuredSpeciesCard(plant: plant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .mask(
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 24)
                    }
                )
            }
        }
    }

    private func featuredSpeciesCard(plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let cachedImage = plant.cachedImage {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 100)
                        .clipped()
                } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 150, height: 100)
                                .clipped()
                        default:
                            featuredPlantGradient
                        }
                    }
                } else {
                    featuredPlantGradient
                }

                if !plant.familyLatin.isEmpty {
                    Text(plant.familyLatin)
                        .font(AppTypography.tagText)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.primaryAmber.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(5)
                }
            }
            .frame(width: 150, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

            VStack(alignment: .leading, spacing: 2) {
                Text(plant.commonName)
                    .font(AppTypography.tagText)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(plant.scientificName)
                    .font(AppTypography.fieldLabel)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            if plant.isAtRisk, let status = plant.atRiskStatus {
                AtRiskBadge(status: status)
            }
        }
        .frame(width: 150)
        .padding(.bottom, 4)
    }

    private var featuredPlantGradient: some View {
        RoundedRectangle(cornerRadius: AppRadius.button)
            .fill(
                LinearGradient(
                    colors: [AppColors.primaryAmber.opacity(0.25), AppColors.primaryAmber.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 150, height: 100)
            .overlay {
                Image("AppIconDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .opacity(0.2)
            }
    }

    // MARK: - Section 4: Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Library")

            VStack(spacing: 0) {
                NavigationLink(destination: TermsListView()) {
                    libraryRow(
                        icon: "text.book.closed.fill",
                        title: "Terms",
                        subtitle: "\(uniqueTermCategories) categories",
                        count: terms.count,
                        color: .orangePrimary
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(AppColors.border)

                NavigationLink(destination: SpeciesGridView()) {
                    libraryRow(
                        icon: "leaf.fill",
                        title: "Species",
                        subtitle: "\(uniqueFamilyCount) families",
                        count: plants.count,
                        color: .orangePrimary
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(AppColors.border)

                NavigationLink(destination: FamiliesListView()) {
                    libraryRow(
                        icon: "leaf.circle.fill",
                        title: "Families",
                        subtitle: "\(uniqueOrderCount) botanical orders",
                        count: families.count,
                        color: .orangePrimary
                    )
                }
                .buttonStyle(.plain)
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
        }
    }

    private func libraryRow(icon: String, title: String, subtitle: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)

                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()

            Text("\(count)")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(color)

            Image(systemName: "chevron.right")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Section 5: Discover

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Discover")

            LazyVGrid(columns: discoverColumns, spacing: 10) {
                NavigationLink(destination: BloomCalendarView()) {
                    discoverCard(
                        icon: "calendar",
                        title: "Bloom Calendar",
                        subtitle: "See what's flowering each month",
                        color: .orangePrimary
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())

                NavigationLink(destination: ConservationView()) {
                    discoverCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "At-Risk Plants",
                        subtitle: "United Plant Savers list",
                        color: .orangePrimary
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())

                NavigationLink(destination: PlantsNearMeView()) {
                    discoverCard(
                        icon: "location.fill",
                        title: "Plants Near Me",
                        subtitle: "Predicted species in your area",
                        color: .orangePrimary
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())

                NavigationLink(destination: ResourcesView()) {
                    discoverCard(
                        icon: "book.closed.fill",
                        title: "Resources",
                        subtitle: "Conservation orgs & societies",
                        color: .orangePrimary
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())
            }
        }
    }

    private func discoverCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 16))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

            Text(title)
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(color.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Shared Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.sectionHeader)
            .foregroundStyle(AppColors.textSecondary)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

// MARK: - Button Styles

private struct SpotlightCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        LearnView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self], inMemory: true)
    .preferredColorScheme(.dark)
}
