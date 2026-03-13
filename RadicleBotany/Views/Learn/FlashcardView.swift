import SwiftUI
import SwiftData

struct FlashcardView: View {
    @Query(sort: \BotanyTerm.term) private var allTerms: [BotanyTerm]
    @Query private var progress: [FlashcardProgress]
    @Query private var userSettingsResults: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    // MARK: - Core Deck State
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var selectedGroup: String? = nil
    @State private var shuffledTerms: [BotanyTerm] = []

    // MARK: - TaoWild State Machine
    @State private var isStarted: Bool = false
    @State private var isFinished: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var showCard: Bool = false
    @State private var shuffleEnabled: Bool = true
    @State private var sessionSize: Int = 20   // 0 = All
    @State private var knewItCount: Int = 0
    @State private var reviewCount: Int = 0
    @State private var showHelpSheet: Bool = false

    // MARK: - Gamification
    @State private var sessionManager = StudySessionManager()
    @State private var showAchievementBanner = false
    @State private var bannerAchievement: Achievement? = nil

    // MARK: - Swipe Direction
    private enum SwipeDirection { case left, right }

    // MARK: - Group Definitions

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

    private var accessibleTerms: [BotanyTerm] { allTerms }

    private var filteredTerms: [BotanyTerm] {
        if let group = selectedGroup {
            return accessibleTerms.filter { parentGroup(for: $0.category) == group }
        }
        return accessibleTerms
    }

    private var activeGroupColor: Color {
        if let group = selectedGroup { return groupDef(for: group).color }
        return .purpleSecondary
    }

    private var sessionCount: Int {
        sessionSize == 0 ? filteredTerms.count : min(sessionSize, filteredTerms.count)
    }

    private var knownCount: Int {
        let termNames = Set(filteredTerms.map(\.term))
        return progress.filter { $0.studyStatus == .known && termNames.contains($0.termName) }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            if filteredTerms.isEmpty {
                emptyState
            } else if !isStarted {
                setupScreen
            } else if isFinished {
                resultsScreen
            } else {
                deckScreen
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
                        withAnimation(.easeOut(duration: 0.3)) { showAchievementBanner = false }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showAchievementBanner)
        .sheet(isPresented: $showHelpSheet) { flashcardHelpSheet }
    }

    // MARK: - Setup Screen

    private var setupScreen: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Title
                VStack(spacing: 6) {
                    Text("Botany Terms")
                        .font(.cormorant(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("461 terms across 7 categories")
                        .font(AppTypography.tagText)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.top, 20)

                // Stats ribbon
                HStack(spacing: 0) {
                    setupStat(value: "\(filteredTerms.count)", label: "AVAILABLE", color: activeGroupColor)
                    Rectangle().fill(AppColors.border).frame(width: 1, height: 36)
                    setupStat(
                        value: sessionSize == 0 ? "All" : "\(sessionSize)",
                        label: "PER SESSION",
                        color: AppColors.textSecondary
                    )
                    Rectangle().fill(AppColors.border).frame(width: 1, height: 36)
                    setupStat(value: "\(sessionCount)", label: "THIS ROUND", color: AppColors.success)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)

                // Category filter chips
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("CATEGORY")
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(name: "All", color: .purpleSecondary, isSelected: selectedGroup == nil) {
                                selectedGroup = nil
                            }
                            ForEach(availableGroups, id: \.self) { group in
                                let def = groupDef(for: group)
                                filterChip(name: group, color: def.color, isSelected: selectedGroup == group) {
                                    selectedGroup = group
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Session size pills
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("CARDS")
                        .padding(.horizontal, 24)

                    HStack(spacing: 8) {
                        ForEach([10, 20, 50, 0], id: \.self) { size in
                            let label = size == 0 ? "All" : "\(size)"
                            let isSelected = sessionSize == size
                            Button { sessionSize = size } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isSelected ? activeGroupColor : AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(isSelected ? activeGroupColor.opacity(0.18) : AppColors.cardBackground)
                                    .cornerRadius(AppRadius.button)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.button)
                                            .strokeBorder(isSelected ? activeGroupColor.opacity(0.35) : AppColors.border, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Order pills
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("ORDER")
                        .padding(.horizontal, 24)

                    HStack(spacing: 8) {
                        orderPill(label: "Shuffle", icon: "shuffle", isSelected: shuffleEnabled) {
                            shuffleEnabled = true
                        }
                        orderPill(label: "Sequential", icon: "list.number", isSelected: !shuffleEnabled) {
                            shuffleEnabled = false
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Begin session ghost button
                Button { startSession() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(AppTypography.inter(size: 14))
                        Text("BEGIN SESSION")
                            .font(AppTypography.inter(size: 14, weight: .heavy))
                            .kerning(1.2)
                    }
                    .foregroundColor(activeGroupColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(activeGroupColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .strokeBorder(activeGroupColor.opacity(0.4), lineWidth: 1.5)
                    )
                    .cornerRadius(AppRadius.button)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }
        }
    }

    // MARK: - Deck Screen

    private var deckScreen: some View {
        VStack(spacing: 0) {

            // Counter + progress bar
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 0) {
                        Text("\(currentIndex + 1)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(activeGroupColor)
                        Text(" / \(shuffledTerms.count)")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(AppColors.textMuted)
                    }

                    Spacer()

                    // Live score dots
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Circle().fill(AppColors.success).frame(width: 6, height: 6)
                            Text("\(knewItCount)")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(AppColors.success)
                        }
                        Text("·")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(AppColors.textMuted)
                        HStack(spacing: 3) {
                            Circle().fill(AppColors.primaryAmber).frame(width: 6, height: 6)
                            Text("\(reviewCount)")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(AppColors.primaryAmber)
                        }
                    }

                    Button { showHelpSheet = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textMuted.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.cardElevated)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(activeGroupColor)
                            .frame(
                                width: shuffledTerms.isEmpty ? 0 :
                                    geo.size.width * CGFloat(currentIndex) / CGFloat(shuffledTerms.count),
                                height: 3
                            )
                            .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Card + directional indicators
            ZStack {
                // Directional indicators (opacity-driven by drag)
                HStack {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 26, weight: .heavy))
                        Text("AGAIN")
                            .font(.system(size: 9, weight: .heavy))
                            .kerning(0.8)
                    }
                    .foregroundColor(AppColors.primaryAmber)
                    .opacity(max(0, min(Double(-dragOffset.width) / 80.0, 0.95)))
                    .padding(.leading, 12)

                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 26, weight: .heavy))
                        Text("MEMORIZED")
                            .font(.system(size: 9, weight: .heavy))
                            .kerning(0.8)
                    }
                    .foregroundColor(AppColors.success)
                    .opacity(max(0, min(Double(dragOffset.width) / 80.0, 0.95)))
                    .padding(.trailing, 12)
                }
                .allowsHitTesting(false)

                // The flashcard
                flashCard(shuffledTerms[currentIndex])
                    .padding(.horizontal, 20)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 25)))
                    .scaleEffect(showCard ? 1.0 : 0.85)
                    .opacity(showCard ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showCard)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                dragOffset = CGSize(width: value.translation.width, height: 0)
                            }
                            .onEnded { gesture in
                                if gesture.translation.width > 80 {
                                    swipeCard(direction: .right)
                                } else if gesture.translation.width < -80 {
                                    swipeCard(direction: .left)
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Hint below card — changes based on flip state
            Group {
                if isFlipped {
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("AGAIN")
                        }
                        .foregroundStyle(AppColors.primaryAmber.opacity(0.45))
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 4) {
                            Text("MEMORIZED")
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(AppColors.success.opacity(0.45))
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                        Text("FLIP")
                    }
                    .foregroundStyle(AppColors.textMuted.opacity(0.35))
                }
            }
            .font(.system(size: 8, weight: .heavy))
            .kerning(0.5)
            .padding(.top, 12)
            .animation(.none, value: isFlipped)

        }
        .padding(.bottom, 160)
    }

    // MARK: - Results Screen

    private var resultsScreen: some View {
        let total = shuffledTerms.count
        let masteryPct = total == 0 ? 0 : Int((Double(knewItCount) / Double(total)) * 100)
        let scoreColor: Color = masteryPct >= 80 ? AppColors.success
                              : masteryPct >= 50 ? AppColors.primaryAmber
                              : .red.opacity(0.8)

        return ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 16)

                // Mastery ring
                ZStack {
                    Circle()
                        .stroke(AppColors.border, lineWidth: 10)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: CGFloat(masteryPct) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.7), value: masteryPct)
                    VStack(spacing: 2) {
                        Text("\(masteryPct)")
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(scoreColor)
                        Text("PERCENT")
                            .font(.system(size: 9, weight: .heavy))
                            .kerning(1.5)
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                // Motivational message
                Text(motivationalMessage(for: masteryPct))
                    .font(AppTypography.inter(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Stat cards
                HStack(spacing: 0) {
                    resultStat(value: "\(knewItCount)", label: "MEMORIZED", color: AppColors.success)
                    Rectangle().fill(AppColors.border).frame(width: 1, height: 44)
                    resultStat(value: "\(reviewCount)", label: "REVIEW", color: AppColors.primaryAmber)
                    Rectangle().fill(AppColors.border).frame(width: 1, height: 44)
                    resultStat(value: "\(total)", label: "TOTAL", color: AppColors.textSecondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)

                // XP earned
                if sessionManager.xpEarned > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.warningAmber)
                        Text("+\(formatXP(sessionManager.xpEarned)) XP earned")
                            .font(AppTypography.inter(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Unlocked achievements
                if !sessionManager.newlyUnlockedAchievements.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(sessionManager.newlyUnlockedAchievements) { achievement in
                            HStack(spacing: 8) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.warning)
                                Text(achievement.name)
                                    .font(AppTypography.bodyText)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.success)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // CTA buttons
                VStack(spacing: 12) {
                    Button { startSession() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .font(AppTypography.inter(size: 14))
                            Text("STUDY AGAIN")
                                .font(AppTypography.inter(size: 14, weight: .heavy))
                                .kerning(1.2)
                        }
                        .foregroundColor(activeGroupColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(activeGroupColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .strokeBorder(activeGroupColor.opacity(0.4), lineWidth: 1.5)
                        )
                        .cornerRadius(AppRadius.button)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Button { restartSession() } label: {
                        Text("Change Settings")
                            .font(AppTypography.inter(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textMuted)
            Text("No terms available")
                .font(AppTypography.sectionHeader)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Flash Card (3D flip combining front + back)

    private func flashCard(_ term: BotanyTerm) -> some View {
        ZStack {
            cardFront(term)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            cardBack(term)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .shadow(
            color: .black.opacity(isFlipped ? 0.2 : 0.1),
            radius: isFlipped ? 16 : 8,
            x: 0,
            y: isFlipped ? 8 : 4
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) { isFlipped.toggle() }
        }
    }

    // MARK: - Card Front

    private func cardFront(_ term: BotanyTerm) -> some View {
        VStack(spacing: 0) {
            // Accent stripe — group color
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [activeGroupColor, activeGroupColor.opacity(0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 3)

            VStack(spacing: 0) {
                // Category badge + Q label
                HStack {
                    Text(term.category.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(0.8)
                        .foregroundColor(activeGroupColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(activeGroupColor.opacity(0.1))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.bottom, 20)

                Spacer(minLength: 0)

                // Term text (scrollable for long terms)
                ScrollView(.vertical, showsIndicators: false) {
                    Text(term.term)
                        .font(.cormorant(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 4)
                }

                Spacer(minLength: 32)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: UIScreen.main.bounds.height * 0.55)
        .background(AppColors.cardBackground)
        .cornerRadius(AppRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .strokeBorder(AppColors.border.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Card Back

    private func cardBack(_ term: BotanyTerm) -> some View {
        VStack(spacing: 0) {
            // Amber accent stripe (always amber on back)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primaryAmber, AppColors.primaryAmber.opacity(0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 3)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {

                    // Header: term name + A / ANSWER label
                    HStack(alignment: .top) {
                        Text(term.term)
                            .font(AppTypography.sectionHeader)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                        Spacer()
                    }

                    // Category pill
                    CategoryPill(text: term.category, color: activeGroupColor)

                    // Illustration — color first, then diagram, no placeholder
                    let bestURL: URL? = {
                        if let c = term.colorImageURL, !c.isEmpty, let u = URL(string: c) { return u }
                        if let d = term.imageURL, !d.isEmpty, let u = URL(string: d) { return u }
                        return nil
                    }()
                    if let url = bestURL {
                        ThrottledAsyncImage(url: url, contentMode: .fit) {
                            EmptyView()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }

                    if !term.descriptionShort.isEmpty {
                        Text(markdownToAttributed(term.descriptionShort))
                            .font(AppTypography.bodyText)
                            .foregroundColor(AppColors.textPrimary)
                            .lineSpacing(4)
                    }

                    // Long description
                    if !term.descriptionLong.isEmpty {
                        Divider().background(AppColors.border)
                        Text(markdownToAttributed(term.descriptionLong))
                            .font(AppTypography.bodyText)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 24)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: UIScreen.main.bounds.height * 0.55)
        .background(AppColors.cardBackground)
        .cornerRadius(AppRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .strokeBorder(AppColors.border.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Reusable Helpers

    private func setupStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .kerning(0.8)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .kerning(0.8)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .kerning(1.2)
            .foregroundColor(AppColors.primaryAmber)
    }

    private func filterChip(name: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(AppTypography.tagText)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : AppColors.cardElevated)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? color : AppColors.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func orderPill(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? activeGroupColor : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? activeGroupColor.opacity(0.18) : AppColors.cardBackground)
            .cornerRadius(AppRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .strokeBorder(isSelected ? activeGroupColor.opacity(0.35) : AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func motivationalMessage(for pct: Int) -> String {
        switch pct {
        case 90...: return "Perfect recall. You've mastered these terms."
        case 75...: return "Excellent work. Nearly there!"
        case 50...: return "Solid progress. Keep reviewing."
        default:    return "Every repetition builds memory. Keep going."
        }
    }

    // MARK: - Session Actions

    private func startSession() {
        let base = shuffleEnabled ? filteredTerms.shuffled() : Array(filteredTerms)
        let deck = sessionSize == 0 ? base : Array(base.prefix(sessionSize))
        shuffledTerms = deck
        currentIndex = 0
        isFlipped = false
        knewItCount = 0
        reviewCount = 0
        dragOffset = .zero
        showCard = false
        sessionManager = StudySessionManager()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isStarted = true
            isFinished = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showCard = true }
        }
    }

    private func restartSession() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isFinished = false
            isStarted = false
        }
        currentIndex = 0
        isFlipped = false
        dragOffset = .zero
        showCard = false
        shuffledTerms = []
        knewItCount = 0
        reviewCount = 0
        sessionManager = StudySessionManager()
    }

    private func swipeCard(direction: SwipeDirection) {
        let flyX: CGFloat = direction == .right ? 600 : -600
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = CGSize(width: flyX, height: 0)
        }
        recordProgress(status: direction == .right ? .known : .learning)
        if direction == .right { knewItCount += 1 } else { reviewCount += 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dragOffset = .zero
            isFlipped = false
            showCard = false

            if currentIndex + 1 >= shuffledTerms.count {
                sessionManager.completeDeck(modelContext: modelContext)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isFinished = true }
                if let first = sessionManager.newlyUnlockedAchievements.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        bannerAchievement = first
                        showAchievementBanner = true
                    }
                }
            } else {
                currentIndex += 1
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { showCard = true }
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

        sessionManager.recordCardReview(mastered: status == .known, modelContext: modelContext)
    }

    // MARK: - Help Sheet

    private var flashcardHelpSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("How it works")
                    .font(.cormorant(size: 26, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, 8)

                helpRow(
                    icon: "hand.tap",
                    color: AppColors.textSecondary,
                    title: "Tap to flip",
                    detail: "Each card shows a term or name on the front. Tap to reveal the definition and details on the back."
                )
                helpRow(
                    icon: "arrow.right",
                    color: AppColors.success,
                    title: "Swipe right — MEMORIZED",
                    detail: "The card is set aside and won't appear again this session."
                )
                helpRow(
                    icon: "arrow.left",
                    color: AppColors.primaryAmber,
                    title: "Swipe left — AGAIN",
                    detail: "You need more practice. The card returns to the deck and will come around again."
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(AppColors.cardBackground.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func helpRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
            }
        }
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
