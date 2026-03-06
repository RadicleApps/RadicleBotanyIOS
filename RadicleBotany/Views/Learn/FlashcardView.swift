import SwiftUI
import SwiftData

struct FlashcardView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \BotanyTerm.term) private var allTerms: [BotanyTerm]
    @Query private var progress: [FlashcardProgress]
    @Query private var userSettingsResults: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var selectedGroup: String? = nil
    @State private var showCompletion = false
    @State private var deckCompleted = false
    @State private var shuffledTerms: [BotanyTerm] = []

    // Gamification
    @State private var sessionManager = StudySessionManager()
    @State private var showAchievementBanner = false
    @State private var bannerAchievement: Achievement? = nil

    // MARK: - Group Definitions (same as TermsListView)

    private static let groupDefinitions: [(name: String, keywords: [String], color: Color)] = [
        ("Leaf",    ["leaf", "leaves", "leaf-like", "stipule", "stipellae"],     .greenSecondary),
        ("Flower",  ["flower", "floral", "petal", "sepal", "anther", "stamen",
                     "staminode", "carpel", "ovary", "style", "corolla",
                     "perianth", "inflorescence", "bract", "bracteole", "spathe"], .orangePrimary),
        ("Stem",    ["stem", "growth"],                                          .orangeLight),
        ("Fruit",   ["fruit", "seed", "cone"],                                   .warningAmber),
        ("Root",    ["root"],                                                    .greenLight),
        ("Surface", ["surface", "texture"],                                      .purpleLight),
        ("Other",   [],                                                          .purpleSecondary)
    ]

    // MARK: - Computed Properties

    private var hasFullAccess: Bool {
        storeManager.isFeatureUnlocked(.fullTermAccess)
    }

    private func parentGroup(for category: String) -> String {
        let lower = category.lowercased()
        for group in Self.groupDefinitions where group.name != "Other" {
            for keyword in group.keywords {
                if lower.contains(keyword) { return group.name }
            }
        }
        return "Other"
    }

    private func groupDef(for name: String) -> (name: String, keywords: [String], color: Color) {
        Self.groupDefinitions.first { $0.name == name } ?? Self.groupDefinitions.last!
    }

    private var availableGroups: [String] {
        let presentGroups = Set(accessibleTerms.map { parentGroup(for: $0.category) })
        return Self.groupDefinitions.map(\.name).filter { presentGroups.contains($0) }
    }

    private var accessibleTerms: [BotanyTerm] {
        allTerms.filter { $0.isFree || hasFullAccess }
    }

    private var filteredTerms: [BotanyTerm] {
        if let group = selectedGroup {
            return accessibleTerms.filter { parentGroup(for: $0.category) == group }
        }
        return accessibleTerms
    }

    private var activeGroupColor: Color {
        if let group = selectedGroup {
            return groupDef(for: group).color
        }
        return .purpleSecondary
    }

    private var knownCount: Int {
        let termNames = Set(filteredTerms.map(\.term))
        return progress.filter { $0.studyStatus == .known && termNames.contains($0.termName) }.count
    }

    private var learningCount: Int {
        let termNames = Set(filteredTerms.map(\.term))
        return progress.filter { $0.studyStatus == .learning && termNames.contains($0.termName) }.count
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if shuffledTerms.isEmpty && filteredTerms.isEmpty {
                emptyState
            } else if deckCompleted {
                completionCard
            } else {
                // Progress header
                progressHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Flashcard pager
                TabView(selection: $currentIndex) {
                    ForEach(Array(shuffledTerms.enumerated()), id: \.element.term) { index, term in
                        FlashcardCardView(
                            term: term,
                            isFlipped: $isFlipped,
                            groupColor: groupDef(for: parentGroup(for: term.category)).color
                        )
                        .tag(index)
                        .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentIndex)

                // Action buttons
                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .background(AppColors.appBackground)
        .onChange(of: currentIndex) { oldIndex, _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                isFlipped = false
            }
            // Auto-record progress for the card the user swiped away from
            if oldIndex < shuffledTerms.count {
                recordProgress(status: .known)
            }
        }
        .onChange(of: isFlipped) { _, flipped in
            // Deck completion: when user flips the last card, they've seen everything
            if flipped && currentIndex == shuffledTerms.count - 1 {
                // Record progress for the final card
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
        .onAppear {
            if shuffledTerms.isEmpty {
                shuffledTerms = filteredTerms.shuffled()
            }
        }
        .onChange(of: selectedGroup) { _, _ in
            shuffledTerms = filteredTerms.shuffled()
            currentIndex = 0
            isFlipped = false
            deckCompleted = false
        }
        .overlay(alignment: .top) {
            if showAchievementBanner, let achievement = bannerAchievement {
                AchievementUnlockBanner(
                    achievement: achievement,
                    onDismiss: {
                        showAchievementBanner = false
                        // Show next achievement if available
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
                    // Auto-show and auto-dismiss
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {}
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

    // MARK: - Group Filter Bar

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(name: "All", color: .purpleSecondary, isSelected: selectedGroup == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGroup = nil
                    }
                }

                ForEach(availableGroups, id: \.self) { group in
                    let def = groupDef(for: group)
                    filterChip(name: group, color: def.color, isSelected: selectedGroup == group) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedGroup = group
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(name: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let bgColor: Color = isSelected ? color : AppColors.cardElevated
        let fgColor: Color = isSelected ? .white : AppColors.textSecondary
        let borderColor: Color = isSelected ? color : AppColors.border

        return Button(action: action) {
            Text(name)
                .font(AppTypography.tagText)
                .foregroundStyle(fgColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(min(currentIndex + 1, shuffledTerms.count)) / \(shuffledTerms.count)")
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

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.cardElevated)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(activeGroupColor)
                        .frame(width: geo.size.width * progressFraction, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .frame(height: 3)
        }
    }

    private var progressFraction: CGFloat {
        guard !shuffledTerms.isEmpty else { return 0 }
        return CGFloat(currentIndex + 1) / CGFloat(shuffledTerms.count)
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

            Image(systemName: "rectangle.on.rectangle.angled")
                .font(AppTypography.inter(size: 48))
                .foregroundStyle(AppColors.textMuted)

            Text("No terms available")
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
                .foregroundStyle(activeGroupColor)

            Text("Deck Complete!")
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 12) {
                completionStat(
                    icon: "rectangle.on.rectangle.angled",
                    label: "Cards Reviewed",
                    value: "\(shuffledTerms.count)",
                    color: .purpleSecondary
                )
                completionStat(
                    icon: "checkmark.circle.fill",
                    label: "Mastered",
                    value: "\(knownCount)",
                    color: .successGreen
                )
                completionStat(
                    icon: "arrow.clockwise",
                    label: "Still Learning",
                    value: "\(learningCount)",
                    color: .orangePrimary
                )

                Divider().background(AppColors.border)

                completionStat(
                    icon: "star.fill",
                    label: "XP Earned",
                    value: "+\(formatXP(sessionManager.xpEarned))",
                    color: .warningAmber
                )
                completionStat(
                    icon: "flame.fill",
                    label: "Study Streak",
                    value: "\(userSettingsResults.first?.safeStudyStreak ?? 0) days",
                    color: .orangePrimary
                )

                // Unlocked achievements
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

            if let groupName = selectedGroup {
                CategoryPill(text: groupName, color: groupDef(for: groupName).color)
            }

            Button("Review Again") {
                withAnimation {
                    shuffledTerms = filteredTerms.shuffled()
                    currentIndex = 0
                    deckCompleted = false
                    isFlipped = false
                    sessionManager = StudySessionManager()
                }
            }
            .buttonStyle(PrimaryButtonStyle(color: activeGroupColor))
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
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if currentIndex < shuffledTerms.count - 1 {
                withAnimation {
                    currentIndex += 1
                }
            } else {
                // Deck complete — trigger gamification
                sessionManager.completeDeck(modelContext: modelContext)
                withAnimation {
                    deckCompleted = true
                }
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
        guard currentIndex < shuffledTerms.count else { return }
        let termName = shuffledTerms[currentIndex].term

        if let existing = progress.first(where: { $0.termName == termName }) {
            existing.studyStatus = status
            existing.lastReviewedDate = .now
            existing.reviewCount += 1
        } else {
            let entry = FlashcardProgress(
                termName: termName,
                status: status.rawValue,
                lastReviewedDate: .now,
                reviewCount: 1
            )
            modelContext.insert(entry)
        }

        // Gamification: record XP
        sessionManager.recordCardReview(mastered: status == .known, modelContext: modelContext)
    }
}

// MARK: - Flashcard Card View

private struct FlashcardCardView: View {
    let term: BotanyTerm
    @Binding var isFlipped: Bool
    let groupColor: Color

    var body: some View {
        ZStack {
            // Front face
            cardFront
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            // Back face
            cardBack
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .animation(.easeInOut(duration: 0.4), value: isFlipped)
        .onTapGesture {
            withAnimation {
                isFlipped.toggle()
            }
        }
    }

    // MARK: - Front Face

    private var cardFront: some View {
        VStack(spacing: 20) {
            Spacer()

            CategoryPill(text: term.category, color: groupColor)

            Text(term.term)
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(groupColor)
                .frame(width: 40, height: 3)

            Text("Tap to reveal")
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
                .stroke(groupColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Back Face

    private var cardBack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(term.term)
                            .font(AppTypography.buttonText)
                            .foregroundStyle(AppColors.textPrimary)

                        CategoryPill(text: term.category, color: groupColor)
                    }
                    Spacer()
                }

                // Illustration (if available)
                if let imageURL = term.imageURL, !imageURL.isEmpty,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                        case .failure:
                            EmptyView()
                        case .empty:
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .fill(AppColors.cardElevated)
                                .frame(height: 120)
                                .overlay(
                                    ProgressView()
                                        .tint(AppColors.textMuted)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Short description
                if !term.descriptionShort.isEmpty {
                    Text(markdownToAttributed(term.descriptionShort))
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(4)
                }

                // Long description
                if !term.descriptionLong.isEmpty {
                    Divider()
                        .background(AppColors.border)

                    Text(markdownToAttributed(term.descriptionLong))
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.badge)
                .stroke(groupColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FlashcardView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [BotanyTerm.self, FlashcardProgress.self], inMemory: true)
    .preferredColorScheme(.dark)
}
