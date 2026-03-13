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

    // MARK: - Category Data

    private struct CategoryInfo {
        let title: String
        let icon: String
        let isAssetIcon: Bool
        let subtitle: String

        init(title: String, icon: String, isAssetIcon: Bool = false, subtitle: String) {
            self.title = title
            self.icon = icon
            self.isAssetIcon = isAssetIcon
            self.subtitle = subtitle
        }
    }

    private var categoryData: [CategoryInfo] {
        [
            CategoryInfo(title: "Flowers", icon: "ph-flower-tulip", isAssetIcon: true, subtitle: "Color, symmetry & form"),
            CategoryInfo(title: "Leaves",  icon: "ph-leaf",         isAssetIcon: true, subtitle: "Shape, margin & venation"),
            CategoryInfo(title: "Fruits",  icon: "ph-cherries",     isAssetIcon: true, subtitle: "Seed types & dispersal"),
            CategoryInfo(title: "Bark",    icon: "ph-tree",         isAssetIcon: true, subtitle: "Texture & growth habit"),
            CategoryInfo(title: "Stems",   icon: "ph-plant",        isAssetIcon: true, subtitle: "Structure & branching"),
            CategoryInfo(title: "Roots",   icon: "carrot.fill",                        subtitle: "Root systems & types")
        ]
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Section 1: Study Tools
                studySection
                    .padding(.top, 12)

                // Section 2: Browse by Trait
                categoriesSection
                    .padding(.top, 28)

                // Section 3: Library
                librarySection
                    .padding(.top, 28)

                // Section 4: Discover
                discoverSection
                    .padding(.top, 28)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(AppColors.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Section 1: Study Tools

    private var studySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Study")

            // Flash Cards + Quiz — equal side-by-side
            HStack(spacing: 10) {
                NavigationLink(destination: FlashcardHubView()) {
                    studyToolCard(
                        title: "Flash Cards",
                        subtitle: "Swipe to learn terms & species",
                        color: AppColors.primaryAmber
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())

                NavigationLink(destination: QuizView()) {
                    studyToolCard(
                        title: "Quiz",
                        subtitle: "Multiple-choice knowledge test",
                        color: AppColors.brandPurple
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())
            }

            // Botanizing — full-width hero
            NavigationLink(destination: BotanizingListView()) {
                botanizingHeroCard
            }
            .buttonStyle(SpotlightCardButtonStyle())
        }
    }

    private func studyToolCard(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.cormorant(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [color.opacity(0.12), color.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(color.opacity(0.2), lineWidth: 0.75)
        )
    }

    private var botanizingHeroCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Botanizing")
                .font(.cormorant(size: 20, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Field scenarios — observe and identify plants through pattern recognition")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.greenSecondary.opacity(0.12), Color.greenSecondary.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(Color.greenSecondary.opacity(0.25), lineWidth: 0.75)
        )
    }

    // MARK: - Section 2: Browse by Trait

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Browse by Trait")

            LazyVGrid(columns: categoryColumns, spacing: 10) {
                ForEach(categoryData, id: \.title) { info in
                    NavigationLink(destination: CategoryDetailView(category: info.title, accentColor: AppColors.brandPurple)) {
                        compactCategoryCard(info: info)
                    }
                    .buttonStyle(SpotlightCardButtonStyle())
                }
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
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: info.icon)
                        .font(.system(size: 17))
                }
            }
            .foregroundStyle(AppColors.brandPurple)
            .frame(width: 22)

            Text(info.title)
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(
            LinearGradient(
                colors: [AppColors.brandPurple.opacity(0.12), AppColors.brandPurple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    // MARK: - Section 3: Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Library")

            VStack(spacing: 0) {
                NavigationLink(destination: TermsListView()) {
                    libraryRow(
                        title: "Terms",
                        count: terms.count
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(AppColors.border)

                NavigationLink(destination: SpeciesGridView()) {
                    libraryRow(
                        title: "Species",
                        count: plants.count
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(AppColors.border)

                NavigationLink(destination: FamiliesListView()) {
                    libraryRow(
                        title: "Families",
                        count: families.count
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

    private func libraryRow(title: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text("\(count)")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.primaryAmber)

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Section 4: Discover
    // Note: "Plants Near Me" is temporarily hidden — NavigationLink preserved below.

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Discover")

            // Bloom Calendar — full-width hero card
            NavigationLink(destination: BloomCalendarView()) {
                discoverHeroCard(
                    title: "Bloom Calendar",
                    subtitle: "See blooms each month across plants",
                    color: AppColors.primaryAmber
                )
            }
            .buttonStyle(SpotlightCardButtonStyle())

            // At-Risk Plants + Resources — equal side-by-side
            HStack(spacing: 10) {
                NavigationLink(destination: ConservationView()) {
                    discoverCard(
                        title: "At-Risk Plants",
                        subtitle: "United Plant Savers list",
                        color: AppColors.brandPurple
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())

                NavigationLink(destination: ResourcesView()) {
                    discoverCard(
                        title: "Resources",
                        subtitle: "Conservation orgs & societies",
                        color: AppColors.success
                    )
                }
                .buttonStyle(SpotlightCardButtonStyle())
            }

            // Plants Near Me — hidden until location issues resolved; keep code for re-enable:
            // NavigationLink(destination: PlantsNearMeView()) {
            //     discoverCard(
            //         title: "Plants Near Me",
            //         subtitle: "Predicted species in your area",
            //         icon: "location.circle",
            //         color: AppColors.primaryAmber
            //     )
            // }
            // .buttonStyle(SpotlightCardButtonStyle())
        }
    }

    private func discoverHeroCard(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.cormorant(size: 18, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            Text(subtitle)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [color.opacity(0.1), color.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(color.opacity(0.2), lineWidth: 0.75)
        )
    }

    private func discoverCard(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.cormorant(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(subtitle)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Shared Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.sectionHeader)
            .foregroundStyle(AppColors.primaryAmber)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

// MARK: - Button Style

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
