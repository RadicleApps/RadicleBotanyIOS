import SwiftUI
import SwiftData

struct PlantFlashcardView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]
    @Query private var progress: [FlashcardProgress]
    @Query private var userSettingsResults: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var selectedFilter: PlantFlashcardFilter = .all
    @State private var deckCompleted = false
    @State private var shuffledPlants: [Plant] = []

    // Gamification
    @State private var sessionManager = StudySessionManager()
    @State private var showAchievementBanner = false
    @State private var bannerAchievement: Achievement? = nil

    /// Optional: pre-filter to a specific family
    var familyFilter: String? = nil

    enum PlantFlashcardFilter: String, CaseIterable {
        case all = "All"
        case leaf = "Leaf"
        case flower = "Flower"
        case stem = "Stem"
        case fruit = "Fruit"

        var color: Color {
            switch self {
            case .all: return .purpleSecondary
            case .leaf: return .greenSecondary
            case .flower: return .orangePrimary
            case .stem: return .orangeLight
            case .fruit: return .warningAmber
            }
        }
    }

    // MARK: - Computed Properties

    private var hasFullAccess: Bool {
        storeManager.isFeatureUnlocked(.fullSpeciesAccess)
    }

    private var accessiblePlants: [Plant] {
        let plants = allPlants.filter { $0.isFree || hasFullAccess }
        if let family = familyFilter {
            return plants.filter { $0.familyLatin == family }
        }
        return plants
    }

    private var filteredPlants: [Plant] {
        accessiblePlants
    }

    private var plantProgress: [FlashcardProgress] {
        progress.filter { $0.deckType == "plant" }
    }

    private var knownCount: Int {
        let names = Set(filteredPlants.map(\.scientificName))
        return plantProgress.filter { $0.studyStatus == .known && names.contains($0.termName) }.count
    }

    private var learningCount: Int {
        let names = Set(filteredPlants.map(\.scientificName))
        return plantProgress.filter { $0.studyStatus == .learning && names.contains($0.termName) }.count
    }

    private var accentColor: Color { selectedFilter.color }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if shuffledPlants.isEmpty && filteredPlants.isEmpty {
                emptyState
            } else if deckCompleted {
                completionCard
            } else {
                progressHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                TabView(selection: $currentIndex) {
                    ForEach(Array(shuffledPlants.enumerated()), id: \.element.scientificName) { index, plant in
                        PlantFlashcardCardView(
                            plant: plant,
                            isFlipped: $isFlipped,
                            accentColor: accentColor
                        )
                        .tag(index)
                        .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentIndex)

                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .background(AppColors.appBackground)
        .onAppear {
            if shuffledPlants.isEmpty {
                shuffledPlants = filteredPlants.shuffled()
            }
        }
        .onChange(of: currentIndex) { oldIndex, _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                isFlipped = false
            }
            // Auto-record progress for the card the user swiped away from
            if oldIndex < shuffledPlants.count {
                recordProgress(status: .known)
            }
        }
        .onChange(of: isFlipped) { _, flipped in
            // Deck completion: when user flips the last card, they've seen everything
            if flipped && currentIndex == shuffledPlants.count - 1 {
                recordProgress(status: .known)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    sessionManager.completeDeck(modelContext: modelContext)
                    withAnimation {
                        deckCompleted = true
                    }
                    if let first = sessionManager.newlyUnlockedAchievements.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            bannerAchievement = first
                            showAchievementBanner = true
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showAchievementBanner, let achievement = bannerAchievement {
                AchievementUnlockBanner(
                    achievement: achievement,
                    onDismiss: {
                        showAchievementBanner = false
                        let unlocked = sessionManager.newlyUnlockedAchievements
                        if let currentIdx = unlocked.firstIndex(where: { $0.name == achievement.name }),
                           currentIdx + 1 < unlocked.count {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                bannerAchievement = unlocked[currentIdx + 1]
                                showAchievementBanner = true
                            }
                        }
                    }
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showAchievementBanner = false
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showAchievementBanner)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(min(currentIndex + 1, shuffledPlants.count)) / \(shuffledPlants.count)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                if knownCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppTypography.inter(size: 11))
                            .foregroundStyle(AppColors.success)
                        Text("\(knownCount) mastered")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.cardElevated)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: geo.size.width * progressFraction, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .frame(height: 3)
        }
    }

    private var progressFraction: CGFloat {
        guard !shuffledPlants.isEmpty else { return 0 }
        return CGFloat(currentIndex + 1) / CGFloat(shuffledPlants.count)
    }

    // MARK: - Swipe Instructions

    private var actionButtons: some View {
        HStack(spacing: 0) {
            Text("← STUDY MORE")
            Spacer()
            Text("·")
            Spacer()
            Text("TAP TO FLIP")
            Spacer()
            Text("·")
            Spacer()
            Text("GOT IT →")
        }
        .font(AppTypography.inter(size: 11, weight: .semibold))
        .tracking(1.5)
        .foregroundStyle(AppColors.textMuted)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(AppTypography.inter(size: 48))
                .foregroundStyle(AppColors.textMuted)
            Text("No species available")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Completion Card

    private var completionCard: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "party.popper.fill")
                .font(AppTypography.inter(size: 56))
                .foregroundStyle(accentColor)

            Text("Deck Complete!")
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 12) {
                completionStat(icon: "leaf.fill", label: "Species Reviewed", value: "\(shuffledPlants.count)", color: .greenSecondary)
                completionStat(icon: "checkmark.circle.fill", label: "Mastered", value: "\(knownCount)", color: .successGreen)
                completionStat(icon: "arrow.clockwise", label: "Still Learning", value: "\(learningCount)", color: .orangePrimary)

                Divider().background(AppColors.border)

                completionStat(icon: "star.fill", label: "XP Earned", value: "+\(formatXP(sessionManager.xpEarned))", color: .warningAmber)
                completionStat(icon: "flame.fill", label: "Study Streak", value: "\(userSettingsResults.first?.safeStudyStreak ?? 0) days", color: .orangePrimary)

                if !sessionManager.newlyUnlockedAchievements.isEmpty {
                    Divider().background(AppColors.border)

                    ForEach(sessionManager.newlyUnlockedAchievements) { achievement in
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                                .font(AppTypography.inter(size: 14))
                                .foregroundStyle(AppColors.warning)
                                .frame(width: 24)
                            Text(achievement.name)
                                .font(AppTypography.bodyText)
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .font(AppTypography.inter(size: 14))
                                .foregroundStyle(AppColors.success)
                        }
                    }
                }
            }
            .padding(AppSpacing.sectionPadding)

            Button("Review Again") {
                withAnimation {
                    shuffledPlants = filteredPlants.shuffled()
                    currentIndex = 0
                    deckCompleted = false
                    isFlipped = false
                    sessionManager = StudySessionManager()
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: accentColor))
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private func completionStat(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Actions

    private func advanceCard() {
        withAnimation(.easeInOut(duration: 0.3)) { isFlipped = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if currentIndex < shuffledPlants.count - 1 {
                withAnimation { currentIndex += 1 }
            } else {
                // Deck complete — trigger gamification
                sessionManager.completeDeck(modelContext: modelContext)
                withAnimation { deckCompleted = true }
                // Show achievement banner if any unlocked
                if let first = sessionManager.newlyUnlockedAchievements.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        bannerAchievement = first
                        showAchievementBanner = true
                    }
                }
            }
        }
    }

    private func recordProgress(status: FlashcardProgress.StudyStatus) {
        guard currentIndex < shuffledPlants.count else { return }
        let name = shuffledPlants[currentIndex].scientificName

        if let existing = plantProgress.first(where: { $0.termName == name }) {
            existing.studyStatus = status
            existing.lastReviewedDate = .now
            existing.reviewCount += 1
        } else {
            let entry = FlashcardProgress(
                termName: name,
                status: status.rawValue,
                lastReviewedDate: .now,
                reviewCount: 1,
                deckType: "plant"
            )
            modelContext.insert(entry)
        }

        // Gamification: record XP
        sessionManager.recordCardReview(mastered: status == .known, modelContext: modelContext)
    }
}

// MARK: - Plant Flashcard Card View

private struct PlantFlashcardCardView: View {
    let plant: Plant
    @Binding var isFlipped: Bool
    let accentColor: Color

    var body: some View {
        ZStack {
            cardFront
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            cardBack
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.easeInOut(duration: 0.4), value: isFlipped)
        .onTapGesture {
            withAnimation { isFlipped.toggle() }
        }
    }

    // MARK: - Front: Image + Common Name

    private var cardFront: some View {
        VStack(spacing: 16) {
            Spacer()

            // Plant image
            if let cachedImage = plant.cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    default:
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(AppColors.cardElevated)
                            .frame(height: 120)
                            .overlay {
                                Image("AppIconDark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .opacity(0.3)
                            }
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppColors.cardElevated)
                    .frame(height: 120)
                    .overlay {
                        Image("AppIconDark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .opacity(0.3)
                    }
            }

            // Common name
            Text(plant.commonName)
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            CategoryPill(text: plant.familyLatin, color: .purpleSecondary)

            Text("What is the scientific name?")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.badge)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Back: Scientific Name + Key Traits

    private var cardBack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Scientific name
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.scientificName)
                        .font(AppTypography.headerTitle)
                        .italic()
                        .foregroundStyle(AppColors.textPrimary)

                    Text(plant.commonName)
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(spacing: 6) {
                    CategoryPill(text: plant.familyLatin, color: .purpleSecondary)
                    if !plant.genus.isEmpty {
                        CategoryPill(text: plant.genus, color: .greenSecondary)
                    }
                }

                Divider().background(AppColors.border)

                // Key traits summary
                VStack(alignment: .leading, spacing: 10) {
                    if let v = plant.leafType { traitRow(label: "Leaf Type", value: v, color: .greenSecondary) }
                    if let v = plant.leafShape { traitRow(label: "Leaf Shape", value: v, color: .greenSecondary) }
                    if let v = plant.leafArrangement { traitRow(label: "Arrangement", value: v, color: .greenSecondary) }
                    if let v = plant.flowerColor { traitRow(label: "Flower Color", value: v, color: .orangePrimary) }
                    if let v = plant.flowerSymmetry { traitRow(label: "Symmetry", value: v, color: .orangePrimary) }
                    if let v = plant.fruitType { traitRow(label: "Fruit Type", value: v, color: .warningAmber) }
                    if let v = plant.growthHabit { traitRow(label: "Growth Habit", value: v, color: .purpleSecondary) }
                    if let v = plant.habitat { traitRow(label: "Habitat", value: v, color: .purpleSecondary) }
                }

                if let bloom = plant.bloomPeriodText {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.macro")
                            .font(AppTypography.inter(size: 11))
                            .foregroundStyle(AppColors.primaryAmber)
                        Text("Blooms: \(bloom)")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.badge)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func traitRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(color)
                .frame(width: 90, alignment: .trailing)

            Text(value)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlantFlashcardView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, FlashcardProgress.self], inMemory: true)
    .preferredColorScheme(.dark)
}
