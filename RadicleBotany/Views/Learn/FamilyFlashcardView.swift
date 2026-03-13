import SwiftUI
import SwiftData

struct FamilyFlashcardView: View {
    @Query(sort: \Family.familyLatin) private var allFamilies: [Family]
    @Query private var progress: [FlashcardProgress]
    @Environment(\.modelContext) private var modelContext

    // Session state
    @State private var isStarted: Bool = false
    @State private var isFinished: Bool = false
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var shuffledFamilies: [Family] = []
    @State private var dragOffset: CGSize = .zero
    @State private var showCard: Bool = false
    @State private var shuffleEnabled: Bool = true
    @State private var sessionSize: Int = 20
    @State private var knewItCount: Int = 0
    @State private var reviewCount: Int = 0
    @State private var showHelpSheet: Bool = false

    // Precomputed family → representative image URL map.
    // Built once at startSession() via a transient fetch — plants released immediately after.
    @State private var familyImageURLs: [String: URL] = [:]

    // Gamification
    @State private var sessionManager = StudySessionManager()
    @State private var showAchievementBanner = false
    @State private var bannerAchievement: Achievement? = nil

    private let accentColor: Color = .purpleSecondary
    private enum SwipeDirection { case left, right }

    // MARK: - Computed Properties

    private var accessibleFamilies: [Family] { allFamilies }

    private var familyProgress: [FlashcardProgress] {
        progress.filter { $0.deckType == "family" }
    }

    private var availableCount: Int { accessibleFamilies.count }

    private var masteryPct: Int {
        guard knewItCount + reviewCount > 0 else { return 0 }
        return Int((Double(knewItCount) / Double(knewItCount + reviewCount)) * 100)
    }

    private var scoreColor: Color {
        masteryPct >= 80 ? AppColors.success : masteryPct >= 50 ? AppColors.warning : AppColors.error
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            if accessibleFamilies.isEmpty {
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
        .sheet(isPresented: $showHelpSheet) { flashcardHelpSheet }
    }

    // MARK: - Setup Screen

    private var setupScreen: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Title
                VStack(spacing: 6) {
                    Text("Plant Families")
                        .font(.cormorant(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("\(availableCount) families")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(.top, 20)

                // Stats ribbon
                HStack(spacing: 0) {
                    setupStat(value: "\(availableCount)", label: "AVAILABLE", color: accentColor)
                    Rectangle().fill(AppColors.border).frame(width: 1, height: 36)
                    setupStat(value: sessionSize == 0 ? "All" : "\(sessionSize)", label: "PER SESSION", color: AppColors.textSecondary)
                    Rectangle().fill(AppColors.border).frame(width: 1, height: 36)
                    setupStat(value: "\(sessionSize == 0 ? availableCount : min(sessionSize, availableCount))", label: "THIS ROUND", color: AppColors.success)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)

                // Session size
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
                                    .foregroundColor(isSelected ? accentColor : AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(isSelected ? accentColor.opacity(0.18) : AppColors.cardBackground)
                                    .cornerRadius(AppRadius.button)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.button)
                                            .strokeBorder(isSelected ? accentColor.opacity(0.35) : AppColors.border, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Order toggle
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

                // Begin session button (ghost style)
                Button {
                    startSession()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(AppTypography.inter(size: 14))
                        Text("BEGIN SESSION")
                            .font(AppTypography.inter(size: 14, weight: .heavy))
                            .kerning(1.2)
                    }
                    .foregroundStyle(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor.opacity(0.12))
                    .cornerRadius(AppRadius.button)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .strokeBorder(accentColor.opacity(0.4), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(availableCount == 0)

                Spacer().frame(height: 120)
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
                            .foregroundColor(accentColor)
                        Text(" / \(shuffledFamilies.count)")
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
                            .fill(accentColor)
                            .frame(
                                width: shuffledFamilies.isEmpty ? 0 :
                                    geo.size.width * CGFloat(currentIndex) / CGFloat(shuffledFamilies.count),
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

                if !shuffledFamilies.isEmpty && currentIndex < shuffledFamilies.count {
                    flashCard(shuffledFamilies[currentIndex])
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
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 16)

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
                    resultStat(value: "\(shuffledFamilies.count)", label: "TOTAL", color: AppColors.textSecondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)

                // XP row
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

                // Action buttons
                VStack(spacing: 12) {
                    // Study Again (ghost)
                    Button {
                        restartSession()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                                .font(AppTypography.inter(size: 14))
                            Text("STUDY AGAIN")
                                .font(AppTypography.inter(size: 14, weight: .heavy))
                                .kerning(1.2)
                        }
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor.opacity(0.12))
                        .cornerRadius(AppRadius.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .strokeBorder(accentColor.opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isStarted = false
                            isFinished = false
                        }
                    } label: {
                        Text("Change Settings")
                            .font(AppTypography.inter(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 40)
            }
        }
    }

    // MARK: - Flash Card (3D Flip Container)

    private func flashCard(_ family: Family) -> some View {
        ZStack {
            cardFront(family)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            cardBack(family)
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

    // MARK: - Card Front (English name → guess Latin)

    private func cardFront(_ family: Family) -> some View {
        VStack(spacing: 0) {
            // Purple accent stripe
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 3)

            VStack(spacing: 0) {
                // FAMILY badge
                HStack {
                    Text("FAMILY")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(0.8)
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.1))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.bottom, 20)

                Spacer(minLength: 0)

                // Family leaf icon
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(accentColor.opacity(0.6))

                Spacer(minLength: 12)

                // English family name
                Text(family.familyEnglish)
                    .font(.cormorant(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .lineLimit(3)
                    .padding(.horizontal, 4)

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

    // MARK: - Card Back (Latin name + traits)

    private func cardBack(_ family: Family) -> some View {
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

                    // Header: Latin name
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.familyLatin)
                                .font(AppTypography.sectionHeader)
                                .italic()
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(2)
                            Text(family.familyEnglish)
                                .font(AppTypography.tagText)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                    }

                    // Taxonomy pills
                    HStack(spacing: 6) {
                        if !family.order.isEmpty {
                            CategoryPill(text: family.order, color: .orangePrimary)
                        }
                        if !family.taxonomicClass.isEmpty {
                            CategoryPill(text: family.taxonomicClass, color: .greenSecondary)
                        }
                    }

                    // Representative plant image — O(1) lookup into precomputed map
                    if let url = familyImageURLs[family.familyLatin] {
                        ThrottledAsyncImage(url: url, contentMode: .fit) {
                            EmptyView()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 140)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }

                    Divider().background(AppColors.border)

                    // Leaf traits
                    let hasLeaf = family.leafType != nil || family.leafAttachment != nil || family.leafArrangement != nil
                        || family.leafShape != nil || family.leafMargin != nil || family.leafApex != nil
                        || family.leafBase != nil || family.leafVenation != nil || family.leafTexture != nil
                        || family.leafStipules != nil || family.leafAdditionalTrait != nil
                    if hasLeaf {
                        traitSection(label: "LEAVES", color: .greenSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = family.leafType             { traitRow(label: "Type",          value: v, color: .greenSecondary) }
                            if let v = family.leafAttachment       { traitRow(label: "Attachment",    value: v, color: .greenSecondary) }
                            if let v = family.leafArrangement      { traitRow(label: "Arrangement",   value: v, color: .greenSecondary) }
                            if let v = family.leafShape            { traitRow(label: "Shape",         value: v, color: .greenSecondary) }
                            if let v = family.leafMargin           { traitRow(label: "Margin",        value: v, color: .greenSecondary) }
                            if let v = family.leafApex             { traitRow(label: "Apex",          value: v, color: .greenSecondary) }
                            if let v = family.leafBase             { traitRow(label: "Base",          value: v, color: .greenSecondary) }
                            if let v = family.leafVenation         { traitRow(label: "Venation",      value: v, color: .greenSecondary) }
                            if let v = family.leafTexture          { traitRow(label: "Texture",       value: v, color: .greenSecondary) }
                            if let v = family.leafStipules         { traitRow(label: "Stipules",      value: v, color: .greenSecondary) }
                            if let v = family.leafAdditionalTrait  { traitRow(label: "Additional",    value: v, color: .greenSecondary) }
                        }
                    }

                    // Stem traits
                    let hasStem = family.stemHabit != nil || family.stemStructure != nil || family.stemBranching != nil
                    if hasStem {
                        traitSection(label: "STEM", color: AppColors.textSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = family.stemHabit     { traitRow(label: "Habit",     value: v, color: AppColors.textSecondary) }
                            if let v = family.stemStructure { traitRow(label: "Structure", value: v, color: AppColors.textSecondary) }
                            if let v = family.stemBranching { traitRow(label: "Branching", value: v, color: AppColors.textSecondary) }
                        }
                    }

                    // Flower traits
                    let hasFlower = family.flowerInflorescence != nil || family.flowerSymmetry != nil || family.flowerPetalCount != nil
                        || family.flowerPetalFusion != nil || family.flowerSepalPresence != nil || family.flowerSepalFusion != nil
                        || family.flowerColor != nil || family.flowerPosition != nil || family.flowerOvaryPosition != nil
                        || family.flowerSexuality != nil || family.flowerFloralPart != nil
                    if hasFlower {
                        traitSection(label: "FLOWERS", color: .orangePrimary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = family.flowerInflorescence  { traitRow(label: "Inflorescence", value: v, color: .orangePrimary) }
                            if let v = family.flowerSymmetry       { traitRow(label: "Symmetry",      value: v, color: .orangePrimary) }
                            if let v = family.flowerPetalCount     { traitRow(label: "Petal Count",   value: v, color: .orangePrimary) }
                            if let v = family.flowerPetalFusion    { traitRow(label: "Petal Fusion",  value: v, color: .orangePrimary) }
                            if let v = family.flowerSepalPresence  { traitRow(label: "Sepals",        value: v, color: .orangePrimary) }
                            if let v = family.flowerSepalFusion    { traitRow(label: "Sepal Fusion",  value: v, color: .orangePrimary) }
                            if let v = family.flowerColor          { traitRow(label: "Color",         value: v, color: .orangePrimary) }
                            if let v = family.flowerPosition       { traitRow(label: "Position",      value: v, color: .orangePrimary) }
                            if let v = family.flowerOvaryPosition  { traitRow(label: "Ovary",        value: v, color: .orangePrimary) }
                            if let v = family.flowerSexuality      { traitRow(label: "Sexuality",     value: v, color: .orangePrimary) }
                            if let v = family.flowerFloralPart     { traitRow(label: "Floral Part",   value: v, color: .orangePrimary) }
                        }
                    }

                    // Fruit & Seed traits
                    let hasFruit = family.fruitType != nil || family.fruitSeedTrait != nil
                    if hasFruit {
                        traitSection(label: "FRUIT & SEED", color: .warningAmber)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = family.fruitType      { traitRow(label: "Fruit Type", value: v, color: .warningAmber) }
                            if let v = family.fruitSeedTrait { traitRow(label: "Seed Trait", value: v, color: .warningAmber) }
                        }
                    }

                    // Root traits
                    let hasRoot = family.rootType != nil || family.rootTrait != nil
                    if hasRoot {
                        traitSection(label: "ROOT", color: AppColors.textSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = family.rootType  { traitRow(label: "Root Type",  value: v, color: AppColors.textSecondary) }
                            if let v = family.rootTrait { traitRow(label: "Root Trait", value: v, color: AppColors.textSecondary) }
                        }
                    }

                    // Ecology traits
                    let hasEcology = family.habitat != nil || family.soil != nil || family.growthHabit != nil
                    if hasEcology {
                        traitSection(label: "ECOLOGY", color: .purpleSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = family.growthHabit { traitRow(label: "Growth Habit", value: v, color: .purpleSecondary) }
                            if let v = family.habitat     { traitRow(label: "Habitat",      value: v, color: .purpleSecondary) }
                            if let v = family.soil        { traitRow(label: "Soil",         value: v, color: .purpleSecondary) }
                        }
                    }

                    // Genera section
                    if !family.genera.isEmpty {
                        Divider().background(AppColors.border)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("GENERA")
                                .font(.system(size: 10, weight: .heavy))
                                .kerning(1.5)
                                .foregroundStyle(AppColors.primaryAmber)
                            Text(family.genera)
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(4)
                        }
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

    // MARK: - Reusable View Helpers

    private func traitSection(label: String, color: Color) -> some View {
        Text(label)
            .font(AppTypography.inter(size: 9, weight: .heavy))
            .tracking(1.5)
            .foregroundStyle(color.opacity(0.7))
            .padding(.top, 4)
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

    private func orderPill(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? accentColor : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? accentColor.opacity(0.18) : AppColors.cardBackground)
            .cornerRadius(AppRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .strokeBorder(isSelected ? accentColor.opacity(0.35) : AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func motivationalMessage(for pct: Int) -> String {
        switch pct {
        case 90...: return "Perfect recall. You've mastered these families."
        case 75...: return "Excellent work. Nearly there!"
        case 50...: return "Solid progress. Keep reviewing."
        default:    return "Every repetition builds memory. Keep going."
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textMuted)
            Text("No families available")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Session Management

    private func startSession() {
        let base = shuffleEnabled ? accessibleFamilies.shuffled() : Array(accessibleFamilies)
        let deck = sessionSize == 0 ? base : Array(base.prefix(sessionSize))
        shuffledFamilies = deck
        // Build family → URL map once. Fetch plants locally so they're released after this
        // function returns — avoids holding 2,327 Plant objects in memory for the view's lifetime.
        if familyImageURLs.isEmpty {
            let fetchedPlants = (try? modelContext.fetch(FetchDescriptor<Plant>())) ?? []
            var urlMap: [String: URL] = [:]
            for plant in fetchedPlants {
                let key = plant.familyLatin
                if urlMap[key] == nil, let urlStr = plant.bestImageURL, let url = URL(string: urlStr) {
                    urlMap[key] = url
                }
            }
            familyImageURLs = urlMap
            // fetchedPlants released here — Plant objects no longer retained by this view
        }
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showCard = true
            }
        }
    }

    private func restartSession() {
        let base = shuffleEnabled ? accessibleFamilies.shuffled() : Array(accessibleFamilies)
        let deck = sessionSize == 0 ? base : Array(base.prefix(sessionSize))
        shuffledFamilies = deck
        currentIndex = 0
        isFlipped = false
        knewItCount = 0
        reviewCount = 0
        dragOffset = .zero
        showCard = false
        sessionManager = StudySessionManager()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isFinished = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showCard = true
            }
        }
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

            if currentIndex + 1 >= shuffledFamilies.count {
                sessionManager.completeDeck(modelContext: modelContext)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isFinished = true
                }
                if let first = sessionManager.newlyUnlockedAchievements.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        bannerAchievement = first
                        showAchievementBanner = true
                    }
                }
            } else {
                currentIndex += 1
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showCard = true
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

        sessionManager.recordCardReview(mastered: status == .known, modelContext: modelContext)
    }

    private func formatXP(_ xp: Int) -> String {
        xp >= 1000 ? String(format: "%.1fk", Double(xp) / 1000.0) : "\(xp)"
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
                    detail: "Each card shows a family name on the front. Tap to reveal its characteristics and representative species on the back."
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
        FamilyFlashcardView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Family.self, Plant.self, FlashcardProgress.self, UserSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
