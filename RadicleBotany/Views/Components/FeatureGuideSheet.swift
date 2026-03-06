import SwiftUI

/// Feature Guide System — Contextual help for every major screen.
///
/// Small, muted `?` buttons that open a clean bottom sheet explaining
/// what the feature is, how to use it, and key details.
///
/// Usage:
///   .featureGuide(.botanize)           // Toolbar modifier
///   InfoButton(guide: .learn)          // Inline placement

// MARK: - Feature Guide Data

struct FeatureGuide: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let sections: [GuideSection]

    struct GuideSection: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let heading: String
        let body: String
    }
}

// MARK: - Guide Library

extension FeatureGuide {

    // MARK: Botanize

    static let botanize = FeatureGuide(
        id: "botanize",
        title: "Plant Identification",
        subtitle: "Point, capture, identify",
        sections: [
            GuideSection(
                icon: "camera.viewfinder",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Three ways to identify plants: Observe (trait-based keying), Capture (photograph + intelligence), or Both (hybrid approach). Each method narrows possibilities differently."
            ),
            GuideSection(
                icon: "leaf.fill",
                iconColor: AppColors.success,
                heading: "Observe mode",
                body: "Select visible traits — leaf shape, flower color, bark texture — and the system narrows matching species. No camera needed. Works offline."
            ),
            GuideSection(
                icon: "camera.fill",
                iconColor: AppColors.brandPurple,
                heading: "Capture mode",
                body: "Photograph any plant organ. The identification engine analyzes the image and returns ranked species matches with confidence scores."
            ),
            GuideSection(
                icon: "arrow.triangle.merge",
                iconColor: AppColors.primaryAmber,
                heading: "Both mode",
                body: "Start with a photograph, then verify or refine with trait selection. Combines visual analysis with morphological data for higher accuracy."
            )
        ]
    )

    static let observe = FeatureGuide(
        id: "observe",
        title: "Field Observations",
        subtitle: "Document what you find",
        sections: [
            GuideSection(
                icon: "eye.fill",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Trait-based plant identification. Select the organ you're examining, then choose observed traits. The system eliminates non-matching species with each selection."
            ),
            GuideSection(
                icon: "square.grid.3x3.fill",
                iconColor: AppColors.brandPurple,
                heading: "Organ selector",
                body: "Start with the plant part you can see most clearly: flower, leaf, stem, fruit, bark, or whole plant. Each organ reveals different diagnostic traits."
            ),
            GuideSection(
                icon: "checkmark.circle.fill",
                iconColor: AppColors.success,
                heading: "Multi-select",
                body: "Select multiple traits within a category. More selections = fewer candidates. The match count updates in real time."
            )
        ]
    )

    // MARK: Journal

    static let journal = FeatureGuide(
        id: "journal",
        title: "Field Journal",
        subtitle: "Your botanical record",
        sections: [
            GuideSection(
                icon: "book.fill",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Every plant you identify is logged here with date, location, and identification details. Your personal herbarium, digital and searchable."
            ),
            GuideSection(
                icon: "calendar",
                iconColor: AppColors.primaryAmber,
                heading: "Streak tracking",
                body: "Consecutive days of botanical activity build your study streak. The counter resets if you miss a day. Streaks unlock achievements."
            ),
            GuideSection(
                icon: "map.fill",
                iconColor: AppColors.brandPurple,
                heading: "Location data",
                body: "Observations include GPS coordinates when available. View your collection on a map to see geographic distribution patterns."
            )
        ]
    )

    // MARK: Learn

    static let learn = FeatureGuide(
        id: "learn",
        title: "Learn Hub",
        subtitle: "Botany at every level",
        sections: [
            GuideSection(
                icon: "graduationcap.fill",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Your botanical education center. Browse species, families, and terminology. Study with flash cards. Track bloom seasons. Explore conservation status."
            ),
            GuideSection(
                icon: "leaf.fill",
                iconColor: AppColors.success,
                heading: "Species & Families",
                body: "179 curated species across 183 families. Each entry includes morphological traits, habitat data, and cross-references to related taxa."
            ),
            GuideSection(
                icon: "text.book.closed.fill",
                iconColor: AppColors.brandPurple,
                heading: "Terminology",
                body: "464 botanical terms with definitions, illustrations, and linked species. Essential vocabulary for field identification."
            ),
            GuideSection(
                icon: "rectangle.stack.fill",
                iconColor: AppColors.primaryAmber,
                heading: "Flash cards",
                body: "Swipe-based study cards for species, families, and terms. Swipe right if you know it, left to review later. Progress is tracked."
            )
        ]
    )

    static let flashCards = FeatureGuide(
        id: "flash_cards",
        title: "Flash Cards",
        subtitle: "Swipe to learn species",
        sections: [
            GuideSection(
                icon: "hand.draw",
                iconColor: AppColors.primaryAmber,
                heading: "How to use",
                body: "Tap a card to flip it and see the answer. Swipe right if you know it. Swipe left to review again later. Work through the deck at your own pace."
            ),
            GuideSection(
                icon: "arrow.counterclockwise",
                iconColor: AppColors.primaryAmber,
                heading: "Progress",
                body: "The counter at the top shows how many cards you've reviewed. Cards you swipe left on will come back for another round."
            ),
            GuideSection(
                icon: "photo.fill",
                iconColor: AppColors.brandPurple,
                heading: "Visual learning",
                body: "Each card includes a species image when available. Visual association strengthens recall during field identification."
            )
        ]
    )

    static let bloomCalendar = FeatureGuide(
        id: "bloom_calendar",
        title: "Bloom Calendar",
        subtitle: "When to find what",
        sections: [
            GuideSection(
                icon: "calendar",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "A month-by-month guide to flowering seasons. See which species are in bloom right now and plan field excursions around peak flowering periods."
            ),
            GuideSection(
                icon: "flower.fill",
                iconColor: AppColors.success,
                heading: "Seasonal data",
                body: "Bloom periods are based on documented phenological data for each species. Actual timing varies by latitude, elevation, and annual conditions."
            )
        ]
    )

    static let plantsNearMe = FeatureGuide(
        id: "plants_near_me",
        title: "Plants Near Me",
        subtitle: "Local biodiversity map",
        sections: [
            GuideSection(
                icon: "location.fill",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Species documented near your current location. Data sourced from occurrence records and community observations."
            ),
            GuideSection(
                icon: "map.fill",
                iconColor: AppColors.primaryAmber,
                heading: "Location accuracy",
                body: "Results depend on GPS accuracy and available occurrence data for your region. Urban areas typically have denser records."
            )
        ]
    )

    static let conservation = FeatureGuide(
        id: "conservation",
        title: "Conservation Status",
        subtitle: "Track what matters",
        sections: [
            GuideSection(
                icon: "exclamationmark.triangle.fill",
                iconColor: AppColors.error,
                heading: "What is this?",
                body: "Species flagged with IUCN conservation status. Critically Endangered, Endangered, Vulnerable, and Near Threatened taxa are highlighted."
            ),
            GuideSection(
                icon: "shield.fill",
                iconColor: AppColors.success,
                heading: "Why it matters",
                body: "Field botanists are often the first to notice population changes. Knowing which species are at risk informs responsible observation and reporting."
            )
        ]
    )

    // MARK: Settings / Dashboard

    static let dashboard = FeatureGuide(
        id: "dashboard",
        title: "Console",
        subtitle: "Your botanical command center",
        sections: [
            GuideSection(
                icon: "gauge.with.dots.needle.bottom.50percent",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Central hub for your account, collection stats, integrations, and app configuration. Everything about your RadicleBotany setup lives here."
            ),
            GuideSection(
                icon: "paintbrush.fill",
                iconColor: AppColors.brandPurple,
                heading: "Appearance",
                body: "Five lighting modes — Night, Light, Dawn, Dusk, and Red Light — each tuned for different environments. All dark-themed and designed for focused study."
            ),
            GuideSection(
                icon: "arrow.triangle.2.circlepath",
                iconColor: AppColors.primaryAmber,
                heading: "Data & sync",
                body: "Manage your botanical data, export observations, and configure cloud sync. Your collection is yours — portable and backed up."
            )
        ]
    )

    static let notionExport = FeatureGuide(
        id: "notion_export",
        title: "Notion Integration",
        subtitle: "Sync your field data",
        sections: [
            GuideSection(
                icon: "arrow.up.right.square",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Export your observations and collection data to a Notion database. Maintains a synced copy of your botanical records for research and sharing."
            ),
            GuideSection(
                icon: "tablecells",
                iconColor: AppColors.primaryAmber,
                heading: "Database format",
                body: "Each observation becomes a Notion page with species, date, location, traits, and images. Structured for easy filtering and analysis."
            )
        ]
    )

    // MARK: Species

    static let species = FeatureGuide(
        id: "species",
        title: "Species Library",
        subtitle: "Browse the full collection",
        sections: [
            GuideSection(
                icon: "leaf.fill",
                iconColor: AppColors.success,
                heading: "What is this?",
                body: "A curated library of plant species. Each entry includes morphological traits, habitat, ecology, and images. Tap any species for the full profile."
            ),
            GuideSection(
                icon: "magnifyingglass",
                iconColor: AppColors.primaryAmber,
                heading: "Search & filter",
                body: "Use the search bar at the top to find species by common or scientific name. Results update as you type."
            ),
            GuideSection(
                icon: "lock.fill",
                iconColor: AppColors.brandPurple,
                heading: "Free vs. paid",
                body: "The first 30 species are free to explore. Subscribe to unlock the full library of species with all trait data and images."
            )
        ]
    )

    // MARK: Families

    static let families = FeatureGuide(
        id: "families",
        title: "Plant Families",
        subtitle: "Taxonomic groupings",
        sections: [
            GuideSection(
                icon: "leaf.circle.fill",
                iconColor: AppColors.brandPurple,
                heading: "What is this?",
                body: "Plant families group species that share key traits. Learning families helps you identify unknown plants by recognizing diagnostic features common to the group."
            ),
            GuideSection(
                icon: "list.bullet",
                iconColor: AppColors.primaryAmber,
                heading: "Browse by letter",
                body: "Families are organized alphabetically. Tap any family to see its diagnostic traits, genera, and related species in the database."
            ),
            GuideSection(
                icon: "arrow.triangle.branch",
                iconColor: AppColors.success,
                heading: "Cross-references",
                body: "Each family links to its member species. Use these connections to study how traits carry across related plants."
            )
        ]
    )

    // MARK: Terms

    static let terms = FeatureGuide(
        id: "terms",
        title: "Botanical Terms",
        subtitle: "The language of botany",
        sections: [
            GuideSection(
                icon: "text.book.closed.fill",
                iconColor: AppColors.brandPurple,
                heading: "What is this?",
                body: "A reference library of botanical terminology. Each term includes a definition, category, and illustrations where available."
            ),
            GuideSection(
                icon: "square.grid.2x2",
                iconColor: AppColors.primaryAmber,
                heading: "Browse by category",
                body: "Terms are grouped by organ and topic — Flowers, Leaves, Fruits, Bark, Stems, and Roots. Tap a category to see all related terms."
            ),
            GuideSection(
                icon: "link",
                iconColor: AppColors.success,
                heading: "Linked species",
                body: "Many terms link to species that exhibit that trait. Tap through to see real examples of each morphological feature."
            )
        ]
    )

    // MARK: Search

    static let search = FeatureGuide(
        id: "search",
        title: "Search",
        subtitle: "Find anything",
        sections: [
            GuideSection(
                icon: "magnifyingglass",
                iconColor: AppColors.primaryAmber,
                heading: "Unified search",
                body: "Search across species, families, and botanical terms simultaneously. Results are grouped by type."
            ),
            GuideSection(
                icon: "line.3.horizontal.decrease.circle",
                iconColor: AppColors.brandPurple,
                heading: "Scope filters",
                body: "Use the tabs — All, Plants, Families, Terms — to narrow results to a specific category."
            ),
            GuideSection(
                icon: "text.magnifyingglass",
                iconColor: AppColors.success,
                heading: "Tips",
                body: "Try scientific names, common names, family names, or term categories. Partial matches work — start typing and results update live."
            )
        ]
    )

    // MARK: Capture

    static let capture = FeatureGuide(
        id: "capture",
        title: "Photo Identification",
        subtitle: "Photograph to identify",
        sections: [
            GuideSection(
                icon: "camera.fill",
                iconColor: AppColors.primaryAmber,
                heading: "How it works",
                body: "Take a photo of any plant organ — flower, leaf, fruit, bark, or whole plant. The identification engine analyzes the image and returns ranked species matches."
            ),
            GuideSection(
                icon: "sparkles",
                iconColor: AppColors.brandPurple,
                heading: "Best results",
                body: "Use clear, well-lit photos. Focus on a single organ. Avoid blurry shots or mixed species. Flowers and fruits are the most diagnostic."
            ),
            GuideSection(
                icon: "chart.bar.fill",
                iconColor: AppColors.success,
                heading: "Confidence scores",
                body: "Each result includes a confidence score. Higher scores indicate a stronger match. Check the top 3 results and compare traits to confirm."
            )
        ]
    )

    // MARK: Both Mode

    static let bothMode = FeatureGuide(
        id: "both_mode",
        title: "Hybrid Identification",
        subtitle: "Photo + traits combined",
        sections: [
            GuideSection(
                icon: "arrow.triangle.merge",
                iconColor: AppColors.primaryAmber,
                heading: "How it works",
                body: "Start with a photo for initial identification, then verify or refine by selecting observed traits. Combines visual analysis with morphological data."
            ),
            GuideSection(
                icon: "checkmark.shield.fill",
                iconColor: AppColors.success,
                heading: "Higher accuracy",
                body: "Adding trait verification to photo results significantly improves identification confidence. Use this mode when you need certainty."
            ),
            GuideSection(
                icon: "list.bullet.rectangle",
                iconColor: AppColors.brandPurple,
                heading: "Trait verification",
                body: "After photo results appear, select traits you can observe on the plant. Matching and conflicting traits are highlighted to guide your decision."
            )
        ]
    )

    // MARK: Resources

    static let resources = FeatureGuide(
        id: "resources",
        title: "Resources",
        subtitle: "Conservation & learning",
        sections: [
            GuideSection(
                icon: "book.closed.fill",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "A curated collection of conservation organizations, botanical societies, and educational resources. External links to trusted sources."
            ),
            GuideSection(
                icon: "globe",
                iconColor: AppColors.brandPurple,
                heading: "Organizations",
                body: "Links to groups like United Plant Savers, botanical gardens, and herbaria. Support conservation by connecting with these communities."
            )
        ]
    )

    // MARK: Profile

    static let profile = FeatureGuide(
        id: "profile",
        title: "Your Profile",
        subtitle: "Stats and achievements",
        sections: [
            GuideSection(
                icon: "person.crop.circle",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Your botanical dashboard — total observations, species identified, study streak, and subscription status at a glance."
            ),
            GuideSection(
                icon: "trophy.fill",
                iconColor: AppColors.primaryAmber,
                heading: "Achievements",
                body: "Earn achievements by reaching milestones — identifying species, building streaks, and exploring the database. Track your progress here."
            ),
            GuideSection(
                icon: "flame.fill",
                iconColor: AppColors.success,
                heading: "Streaks",
                body: "Your streak counts consecutive days of botanical activity. Use the app daily to keep it going. Streaks are displayed on your profile."
            )
        ]
    )

    // MARK: Collections

    static let collections = FeatureGuide(
        id: "collections",
        title: "Collections",
        subtitle: "Organize your observations",
        sections: [
            GuideSection(
                icon: "folder.fill",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "Collections let you group observations by theme — habitat, season, project, or any category you choose. Create custom collections to organize your field work."
            ),
            GuideSection(
                icon: "plus.circle.fill",
                iconColor: AppColors.success,
                heading: "Creating collections",
                body: "Tap 'New Collection' to create a custom grouping. Add observations to any collection from the observation detail screen."
            ),
            GuideSection(
                icon: "tray.full.fill",
                iconColor: AppColors.brandPurple,
                heading: "Built-in collections",
                body: "Default collections — Favorites, Field Notes, and Study List — are ready to use. Add your own alongside them."
            )
        ]
    )

    // MARK: Category Detail

    static let categoryDetail = FeatureGuide(
        id: "category_detail",
        title: "Trait Category",
        subtitle: "Explore morphological traits",
        sections: [
            GuideSection(
                icon: "square.grid.2x2",
                iconColor: AppColors.primaryAmber,
                heading: "What is this?",
                body: "All botanical terms for a specific plant organ. Browse traits for flowers, leaves, fruits, bark, stems, or roots."
            ),
            GuideSection(
                icon: "photo",
                iconColor: AppColors.brandPurple,
                heading: "Illustrations",
                body: "Many terms include illustrations showing the trait. Tap any term card to see its full definition and linked species."
            ),
            GuideSection(
                icon: "leaf.fill",
                iconColor: AppColors.success,
                heading: "Field use",
                body: "Learn these traits to improve your identification skills. Recognizing leaf margins, flower symmetry, or fruit types narrows species quickly."
            )
        ]
    )
}

// MARK: - Info Button Component

struct InfoButton: View {
    let guide: FeatureGuide
    var style: InfoButtonStyle = .inline

    @State private var showGuide = false

    enum InfoButtonStyle {
        case inline
        case toolbar
    }

    var body: some View {
        Button {
            HapticFeedback.tap()
            showGuide = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(AppTypography.inter(size: style == .toolbar ? 15 : 13, weight: .medium))
                .foregroundColor(AppColors.textMuted.opacity(0.5))
        }
        .sheet(isPresented: $showGuide) {
            FeatureGuideSheet(guide: guide)
        }
    }
}

// MARK: - Feature Guide Sheet

struct FeatureGuideSheet: View {
    let guide: FeatureGuide
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(guide.title)
                                    .font(AppTypography.inter(size: 20, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary)

                                Text(guide.subtitle)
                                    .font(AppTypography.inter(size: 13, weight: .regular))
                                    .foregroundColor(AppColors.textMuted)
                            }

                            Spacer()

                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(AppTypography.inter(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textMuted)
                                    .frame(width: 30, height: 30)
                                    .background(AppColors.cardElevated)
                                    .clipShape(Circle())
                            }
                        }

                        Rectangle()
                            .fill(AppColors.border)
                            .frame(height: 0.5)
                            .padding(.top, 4)
                    }

                    // Sections
                    ForEach(guide.sections) { section in
                        guideSectionRow(section)
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, 24)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func guideSectionRow(_ section: FeatureGuide.GuideSection) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(section.iconColor.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: section.icon)
                    .font(AppTypography.inter(size: 15, weight: .medium))
                    .foregroundColor(section.iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(section.heading)
                    .font(AppTypography.inter(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(section.body)
                    .font(AppTypography.inter(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - View Extension for Toolbar

extension View {
    func featureGuide(_ guide: FeatureGuide) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                InfoButton(guide: guide, style: .toolbar)
            }
        }
    }
}
