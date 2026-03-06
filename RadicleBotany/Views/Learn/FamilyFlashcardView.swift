import SwiftUI
import SwiftData

struct FamilyFlashcardView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Family.familyLatin) private var allFamilies: [Family]
    @Query private var progress: [FlashcardProgress]
    @Query private var userSettingsResults: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var deckCompleted = false
    @State private var shuffledFamilies: [Family] = []

    // Gamification
    @State private var sessionManager = StudySessionManager()
    @State private var showAchievementBanner = false
    @State private var bannerAchievement: Achievement? = nil

    // MARK: - Computed Properties

    private var hasFullAccess: Bool {
        storeManager.isFeatureUnlocked(.fullFamilyAccess)
    }

    private var accessibleFamilies: [Family] {
        allFamilies.filter { $0.isFree || hasFullAccess }
    }

    private var familyProgress: [FlashcardProgress] {
        progress.filter { $0.deckType == "family" }
    }

    private var knownCount: Int {
        let names = Set(accessibleFamilies.map(\.familyLatin))
        return familyProgress.filter { $0.studyStatus == .known && names.contains($0.termName) }.count
    }

    private var learningCount: Int {
        let names = Set(accessibleFamilies.map(\.familyLatin))
        return familyProgress.filter { $0.studyStatus == .learning && names.contains($0.termName) }.count
    }

    private let accentColor: Color = .purpleSecondary

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if shuffledFamilies.isEmpty && accessibleFamilies.isEmpty {
                emptyState
            } else if deckCompleted {
                completionCard
            } else {
                progressHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                TabView(selection: $currentIndex) {
                    ForEach(Array(shuffledFamilies.enumerated()), id: \.element.familyLatin) { index, family in
                        FamilyFlashcardCardView(
                            family: family,
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
            if shuffledFamilies.isEmpty {
                shuffledFamilies = accessibleFamilies.shuffled()
            }
        }
        .onChange(of: currentIndex) { oldIndex, _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                isFlipped = false
            }
            // Auto-record progress for the card the user swiped away from
            if oldIndex < shuffledFamilies.count {
                recordProgress(status: .known)
            }
        }
        .onChange(of: isFlipped) { _, flipped in
            // Deck completion: when user flips the last card, they've seen everything
            if flipped && currentIndex == shuffledFamilies.count - 1 {
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
                Text("\(min(currentIndex + 1, shuffledFamilies.count)) / \(shuffledFamilies.count)")
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
        guard !shuffledFamilies.isEmpty else { return 0 }
        return CGFloat(currentIndex + 1) / CGFloat(shuffledFamilies.count)
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
            Image(systemName: "leaf.circle.fill")
                .font(AppTypography.inter(size: 48))
                .foregroundStyle(AppColors.textMuted)
            Text("No families available")
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
                completionStat(icon: "leaf.circle.fill", label: "Families Reviewed", value: "\(shuffledFamilies.count)", color: .purpleSecondary)
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
                    shuffledFamilies = accessibleFamilies.shuffled()
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
            if currentIndex < shuffledFamilies.count - 1 {
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
        guard currentIndex < shuffledFamilies.count else { return }
        let name = shuffledFamilies[currentIndex].familyLatin

        if let existing = familyProgress.first(where: { $0.termName == name }) {
            existing.studyStatus = status
            existing.lastReviewedDate = .now
            existing.reviewCount += 1
        } else {
            let entry = FlashcardProgress(
                termName: name,
                status: status.rawValue,
                lastReviewedDate: .now,
                reviewCount: 1,
                deckType: "family"
            )
            modelContext.insert(entry)
        }

        // Gamification: record XP
        sessionManager.recordCardReview(mastered: status == .known, modelContext: modelContext)
    }
}

// MARK: - Family Flashcard Card View

private struct FamilyFlashcardCardView: View {
    let family: Family
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

    // MARK: - Front: English Name → guess the Latin

    private var cardFront: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(AppTypography.inter(size: 56))
                .foregroundStyle(accentColor.opacity(0.6))

            Text(family.familyEnglish)
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 40, height: 3)

            Text("What is the Latin name?")
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

    // MARK: - Back: Latin Name + Key Traits

    private var cardBack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(family.familyLatin)
                        .font(AppTypography.headerTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(family.familyEnglish)
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(spacing: 6) {
                    if !family.order.isEmpty {
                        CategoryPill(text: family.order, color: .orangePrimary)
                    }
                    if !family.taxonomicClass.isEmpty {
                        CategoryPill(text: family.taxonomicClass, color: .greenSecondary)
                    }
                }

                Divider().background(AppColors.border)

                // Key identifying traits
                VStack(alignment: .leading, spacing: 10) {
                    if let v = family.leafType { traitRow(label: "Leaf Type", value: v, color: .greenSecondary) }
                    if let v = family.leafArrangement { traitRow(label: "Arrangement", value: v, color: .greenSecondary) }
                    if let v = family.flowerSymmetry { traitRow(label: "Symmetry", value: v, color: .orangePrimary) }
                    if let v = family.flowerPetalCount { traitRow(label: "Petal Count", value: v, color: .orangePrimary) }
                    if let v = family.fruitType { traitRow(label: "Fruit Type", value: v, color: .warningAmber) }
                    if let v = family.growthHabit { traitRow(label: "Growth Habit", value: v, color: .purpleSecondary) }
                }

                // Genera preview
                if !family.genera.isEmpty {
                    Divider().background(AppColors.border)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("GENERA")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)

                        Text(family.genera)
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(3)
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
        FamilyFlashcardView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Family.self, FlashcardProgress.self], inMemory: true)
    .preferredColorScheme(.dark)
}
