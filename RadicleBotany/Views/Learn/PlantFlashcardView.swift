import SwiftUI
import SwiftData

struct PlantFlashcardView: View {
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]
    @Query private var progress: [FlashcardProgress]
    @Query private var userSettingsResults: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    // MARK: - Core Deck State
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var shuffledPlants: [Plant] = []

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

    /// Optional: pre-filter to a specific family
    var familyFilter: String? = nil

    // MARK: - Fixed accent
    private let accentColor: Color = .greenSecondary

    // MARK: - Computed Properties

    private var accessiblePlants: [Plant] {
        if let family = familyFilter {
            return allPlants.filter { $0.familyLatin == family }
        }
        return Array(allPlants)
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

    private var sessionCount: Int {
        sessionSize == 0 ? filteredPlants.count : min(sessionSize, filteredPlants.count)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            if filteredPlants.isEmpty {
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
                    Text(familyFilter ?? "Plant Species")
                        .font(.cormorant(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(familyFilter != nil ? "Species in this family" : "2,330+ species with full traits")
                        .font(AppTypography.tagText)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.top, 20)

                // Stats ribbon
                HStack(spacing: 0) {
                    setupStat(value: "\(filteredPlants.count)", label: "AVAILABLE", color: accentColor)
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
                    .foregroundColor(accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .strokeBorder(accentColor.opacity(0.4), lineWidth: 1.5)
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
                            .foregroundColor(accentColor)
                        Text(" / \(shuffledPlants.count)")
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
                                width: shuffledPlants.isEmpty ? 0 :
                                    geo.size.width * CGFloat(currentIndex) / CGFloat(shuffledPlants.count),
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
                // Directional indicators
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
                flashCard(shuffledPlants[currentIndex])
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
        let total = shuffledPlants.count
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
                        .foregroundColor(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .strokeBorder(accentColor.opacity(0.4), lineWidth: 1.5)
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
            Image(systemName: "leaf.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textMuted)
            Text("No species available")
                .font(AppTypography.sectionHeader)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Flash Card (3D flip combining front + back)

    private func flashCard(_ plant: Plant) -> some View {
        ZStack {
            cardFront(plant)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            cardBack(plant)
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

    private func cardFront(_ plant: Plant) -> some View {
        VStack(spacing: 0) {
            // Green accent stripe
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.6)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 3)

            VStack(spacing: 0) {
                // SPECIES badge + Q label
                HStack {
                    Text("SPECIES")
                        .font(.system(size: 9, weight: .heavy))
                        .kerning(0.8)
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.1))
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.bottom, 16)

                Spacer(minLength: 0)

                // Plant image
                let info = plant.cachedImageInfo
                if let info, info.isFullSize {
                    Image(uiImage: info.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
                    ThrottledAsyncImage(url: url, contentMode: .fit) {
                        EmptyView()
                    }
                    .frame(maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }

                Spacer(minLength: 12)

                // Common name
                Text(plant.titleCasedCommonName)
                    .font(AppTypography.inter(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                CategoryPill(text: plant.familyLatin, color: .purpleSecondary)
                    .padding(.top, 8)

                Spacer(minLength: 16)

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

    private func cardBack(_ plant: Plant) -> some View {
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

                    // Header: scientific name + A / ANSWER label
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plant.scientificName)
                                .font(AppTypography.sectionHeader)
                                .italic()
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(2)
                            Text(plant.titleCasedCommonName)
                                .font(AppTypography.tagText)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                    }

                    // Family + genus pills
                    HStack(spacing: 6) {
                        CategoryPill(text: plant.familyLatin, color: .purpleSecondary)
                        if !plant.genus.isEmpty {
                            CategoryPill(text: plant.genus, color: accentColor)
                        }
                    }

                    // Plant image — cached first, then network, no placeholder
                    let backInfo = plant.cachedImageInfo
                    if let backInfo, backInfo.isFullSize {
                        Image(uiImage: backInfo.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 140)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    } else if let imageURL = plant.bestImageURL, let url = URL(string: imageURL) {
                        ThrottledAsyncImage(url: url, contentMode: .fit) {
                            EmptyView()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 140)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }

                    Divider().background(AppColors.border)

                    // Leaf traits
                    let hasLeaf = plant.leafType != nil || plant.leafAttachment != nil || plant.leafArrangement != nil
                        || plant.leafShape != nil || plant.leafMargin != nil || plant.leafApex != nil
                        || plant.leafBase != nil || plant.leafVenation != nil || plant.leafTexture != nil
                        || plant.leafStipules != nil
                    if hasLeaf {
                        traitSection(label: "LEAVES", color: .greenSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = plant.leafType        { traitRow(label: "Type",         value: v, color: .greenSecondary) }
                            if let v = plant.leafAttachment  { traitRow(label: "Attachment",   value: v, color: .greenSecondary) }
                            if let v = plant.leafArrangement { traitRow(label: "Arrangement",  value: v, color: .greenSecondary) }
                            if let v = plant.leafShape       { traitRow(label: "Shape",        value: v, color: .greenSecondary) }
                            if let v = plant.leafMargin      { traitRow(label: "Margin",       value: v, color: .greenSecondary) }
                            if let v = plant.leafApex        { traitRow(label: "Apex",         value: v, color: .greenSecondary) }
                            if let v = plant.leafBase        { traitRow(label: "Base",         value: v, color: .greenSecondary) }
                            if let v = plant.leafVenation    { traitRow(label: "Venation",     value: v, color: .greenSecondary) }
                            if let v = plant.leafTexture     { traitRow(label: "Texture",      value: v, color: .greenSecondary) }
                            if let v = plant.leafStipules    { traitRow(label: "Stipules",     value: v, color: .greenSecondary) }
                        }
                    }

                    // Stem traits
                    let hasStem = plant.stemHabit != nil || plant.stemStructure != nil || plant.stemBranching != nil
                    if hasStem {
                        traitSection(label: "STEM", color: AppColors.textSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = plant.stemHabit     { traitRow(label: "Habit",      value: v, color: AppColors.textSecondary) }
                            if let v = plant.stemStructure { traitRow(label: "Structure",  value: v, color: AppColors.textSecondary) }
                            if let v = plant.stemBranching { traitRow(label: "Branching",  value: v, color: AppColors.textSecondary) }
                        }
                    }

                    // Flower traits
                    let hasFlower = plant.flowerInflorescence != nil || plant.flowerSymmetry != nil || plant.flowerPetalCount != nil
                        || plant.flowerPetalFusion != nil || plant.flowerSepalPresence != nil || plant.flowerSepalFusion != nil
                        || plant.flowerColor != nil || plant.flowerPosition != nil || plant.flowerOvaryPosition != nil
                        || plant.flowerSexuality != nil || plant.flowerFloralPart != nil
                    if hasFlower {
                        traitSection(label: "FLOWERS", color: .orangePrimary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = plant.flowerInflorescence  { traitRow(label: "Inflorescence",  value: v, color: .orangePrimary) }
                            if let v = plant.flowerSymmetry       { traitRow(label: "Symmetry",       value: v, color: .orangePrimary) }
                            if let v = plant.flowerPetalCount     { traitRow(label: "Petal Count",    value: v, color: .orangePrimary) }
                            if let v = plant.flowerPetalFusion    { traitRow(label: "Petal Fusion",   value: v, color: .orangePrimary) }
                            if let v = plant.flowerSepalPresence  { traitRow(label: "Sepals",         value: v, color: .orangePrimary) }
                            if let v = plant.flowerSepalFusion    { traitRow(label: "Sepal Fusion",   value: v, color: .orangePrimary) }
                            if let v = plant.flowerColor          { traitRow(label: "Color",          value: v, color: .orangePrimary) }
                            if let v = plant.flowerPosition       { traitRow(label: "Position",       value: v, color: .orangePrimary) }
                            if let v = plant.flowerOvaryPosition  { traitRow(label: "Ovary",         value: v, color: .orangePrimary) }
                            if let v = plant.flowerSexuality      { traitRow(label: "Sexuality",      value: v, color: .orangePrimary) }
                            if let v = plant.flowerFloralPart     { traitRow(label: "Floral Part",    value: v, color: .orangePrimary) }
                        }
                    }

                    // Fruit & Seed traits
                    let hasFruit = plant.fruitType != nil || plant.fruitSeedTrait != nil
                    if hasFruit {
                        traitSection(label: "FRUIT & SEED", color: .warningAmber)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = plant.fruitType      { traitRow(label: "Fruit Type",  value: v, color: .warningAmber) }
                            if let v = plant.fruitSeedTrait { traitRow(label: "Seed Trait",  value: v, color: .warningAmber) }
                        }
                    }

                    // Root traits
                    if let v = plant.rootType {
                        traitSection(label: "ROOT", color: AppColors.textSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            traitRow(label: "Root Type", value: v, color: AppColors.textSecondary)
                        }
                    }

                    // Ecology traits
                    let hasEcology = plant.habitat != nil || plant.soil != nil || plant.growthHabit != nil
                    if hasEcology {
                        traitSection(label: "ECOLOGY", color: .purpleSecondary)
                        VStack(alignment: .leading, spacing: 10) {
                            if let v = plant.growthHabit { traitRow(label: "Growth Habit", value: v, color: .purpleSecondary) }
                            if let v = plant.habitat     { traitRow(label: "Habitat",      value: v, color: .purpleSecondary) }
                            if let v = plant.soil        { traitRow(label: "Soil",         value: v, color: .purpleSecondary) }
                        }
                    }

                    // Bloom period
                    if let bloom = plant.bloomPeriodText {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.macro")
                                .font(AppTypography.inter(size: 11))
                                .foregroundColor(AppColors.primaryAmber)
                            Text("Blooms: \(bloom)")
                                .font(AppTypography.tagText)
                                .foregroundColor(AppColors.textSecondary)
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

    private func traitSection(label: String, color: Color) -> some View {
        Text(label)
            .font(AppTypography.inter(size: 9, weight: .heavy))
            .tracking(1.5)
            .foregroundColor(color.opacity(0.7))
            .padding(.top, 4)
    }

    private func traitRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(color)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .font(AppTypography.bodyText)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
        }
    }

    private func motivationalMessage(for pct: Int) -> String {
        switch pct {
        case 90...: return "Perfect recall. You've mastered these species."
        case 75...: return "Excellent work. Nearly there!"
        case 50...: return "Solid progress. Keep reviewing."
        default:    return "Every repetition builds memory. Keep going."
        }
    }

    // MARK: - Session Actions

    private func startSession() {
        let base = shuffleEnabled ? filteredPlants.shuffled() : Array(filteredPlants)
        let deck = sessionSize == 0 ? base : Array(base.prefix(sessionSize))
        shuffledPlants = deck
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
        shuffledPlants = []
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

            if currentIndex + 1 >= shuffledPlants.count {
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
                    detail: "Each card shows a species name on the front. Tap to reveal its family, traits, and details on the back."
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
        PlantFlashcardView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, FlashcardProgress.self], inMemory: true)
    .preferredColorScheme(.dark)
}
