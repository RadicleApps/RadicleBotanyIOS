import SwiftUI
import SwiftData

struct QuizView: View {
    @Query(sort: \BotanyTerm.term) private var allTerms: [BotanyTerm]
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]
    @Query(sort: \Family.familyLatin) private var allFamilies: [Family]
    @Query private var userSettingsResults: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    // Phase
    @State private var phase: QuizPhase = .setup

    // Setup
    @State private var quizCategory: QuizCategory = .all
    @State private var questionCount: Int = 25
    @State private var traitFilter: String? = nil

    // Quiz state
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var outcome: QuizOutcome = .unanswered
    @State private var answers: [QuizAnswer] = []
    @State private var startTime: Date = .now
    @State private var endTime: Date = .now

    // Study More queue
    @State private var studyMoreQueue: [QuizQuestion] = []
    @State private var showStudyMoreBanner: Bool = false
    @State private var studyMoreBannerCount: Int = 0

    // Study sheets (for Study button and explanation card links)
    @State private var studySheetPlant: Plant? = nil
    @State private var studySheetFamily: Family? = nil
    @State private var studySheetTerm: BotanyTerm? = nil

    // Gamification
    @State private var sessionManager = StudySessionManager()

    // MARK: - Types

    enum QuizPhase {
        case setup, active, results
    }

    enum QuizOutcome: Equatable {
        case unanswered
        case correct(answer: String)
        case incorrect(answer: String)
        case revealed

        var isCommitted: Bool {
            if case .unanswered = self { return false }
            return true
        }
        var selectedAnswer: String? {
            switch self {
            case .correct(let a): return a
            case .incorrect(let a): return a
            default: return nil
            }
        }
        var isAnswered: Bool {
            switch self {
            case .correct, .incorrect: return true
            default: return false
            }
        }
    }

    enum QuizCategory: String, CaseIterable {
        case all = "All"
        case taxonomy = "Taxonomy"
        case leaves = "Leaves"
        case flowers = "Flowers"
        case fruitsSeeds = "Fruits & Seeds"
        case stemsRoots = "Stems & Roots"
        case ecology = "Ecology"
        case terms = "Terms"
        case families = "Families"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .taxonomy: return "list.bullet.indent"
            case .leaves: return "leaf.fill"
            case .flowers: return "camera.macro"
            case .fruitsSeeds: return "drop.fill"
            case .stemsRoots: return "laurel.leading"
            case .ecology: return "mountain.2.fill"
            case .terms: return "text.book.closed.fill"
            case .families: return "leaf.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .all: return AppColors.primaryAmber
            case .taxonomy: return .purpleSecondary
            case .leaves: return .greenSecondary
            case .flowers: return .orangePrimary
            case .fruitsSeeds: return .warningAmber
            case .stemsRoots: return .greenLight
            case .ecology: return .purpleSecondary
            case .terms: return AppColors.primaryAmber
            case .families: return .greenSecondary
            }
        }

        var subtitle: String {
            switch self {
            case .all: return "Every category combined"
            case .taxonomy: return "Names, families & classification"
            case .leaves: return "Shape, margin, venation & more"
            case .flowers: return "Color, symmetry, petals & more"
            case .fruitsSeeds: return "Fruit type & seed traits"
            case .stemsRoots: return "Habit, structure & root type"
            case .ecology: return "Habitat, soil & growth habit"
            case .terms: return "Botanical terminology"
            case .families: return "Plant family identification"
            }
        }
    }

    // MARK: - Trait Specification

    struct TraitSpec {
        let key: String
        let displayName: String
        let getValue: (Plant) -> String?
    }

    struct FamilyTraitSpec {
        let key: String
        let displayName: String
        let getValue: (Family) -> String?
    }

    // MARK: - Trait Definitions

    private var leafTraits: [TraitSpec] {
        [
            TraitSpec(key: "leafType", displayName: "Leaf Type", getValue: { $0.leafType }),
            TraitSpec(key: "leafArrangement", displayName: "Leaf Arrangement", getValue: { $0.leafArrangement }),
            TraitSpec(key: "leafShape", displayName: "Leaf Shape", getValue: { $0.leafShape }),
            TraitSpec(key: "leafMargin", displayName: "Leaf Margin", getValue: { $0.leafMargin }),
            TraitSpec(key: "leafApex", displayName: "Leaf Apex", getValue: { $0.leafApex }),
            TraitSpec(key: "leafBase", displayName: "Leaf Base", getValue: { $0.leafBase }),
            TraitSpec(key: "leafVenation", displayName: "Leaf Venation", getValue: { $0.leafVenation }),
            TraitSpec(key: "leafTexture", displayName: "Leaf Texture", getValue: { $0.leafTexture }),
            TraitSpec(key: "leafStipules", displayName: "Stipules", getValue: { $0.leafStipules }),
        ]
    }

    private var flowerTraits: [TraitSpec] {
        [
            TraitSpec(key: "flowerColor", displayName: "Flower Color", getValue: { $0.flowerColor }),
            TraitSpec(key: "flowerSymmetry", displayName: "Flower Symmetry", getValue: { $0.flowerSymmetry }),
            TraitSpec(key: "flowerPetalCount", displayName: "Petal Count", getValue: { $0.flowerPetalCount }),
            TraitSpec(key: "flowerPetalFusion", displayName: "Petal Fusion", getValue: { $0.flowerPetalFusion }),
            TraitSpec(key: "flowerInflorescence", displayName: "Inflorescence", getValue: { $0.flowerInflorescence }),
            TraitSpec(key: "flowerOvaryPosition", displayName: "Ovary Position", getValue: { $0.flowerOvaryPosition }),
            TraitSpec(key: "flowerSepalPresence", displayName: "Sepal Presence", getValue: { $0.flowerSepalPresence }),
            TraitSpec(key: "flowerSepalFusion", displayName: "Sepal Fusion", getValue: { $0.flowerSepalFusion }),
            TraitSpec(key: "flowerPosition", displayName: "Flower Position", getValue: { $0.flowerPosition }),
            TraitSpec(key: "flowerSexuality", displayName: "Floral Sex", getValue: { $0.flowerSexuality }),
            TraitSpec(key: "flowerFloralPart", displayName: "Floral Part", getValue: { $0.flowerFloralPart }),
        ]
    }

    private var fruitSeedTraits: [TraitSpec] {
        [
            TraitSpec(key: "fruitType", displayName: "Fruit Type", getValue: { $0.fruitType }),
            TraitSpec(key: "fruitSeedTrait", displayName: "Seed Trait", getValue: { $0.fruitSeedTrait }),
            TraitSpec(key: "rootType", displayName: "Root Type", getValue: { $0.rootType }),
        ]
    }

    private var stemRootTraits: [TraitSpec] {
        [
            TraitSpec(key: "stemHabit", displayName: "Stem Habit", getValue: { $0.stemHabit }),
            TraitSpec(key: "stemStructure", displayName: "Stem Structure", getValue: { $0.stemStructure }),
            TraitSpec(key: "stemBranching", displayName: "Stem Branching", getValue: { $0.stemBranching }),
        ]
    }

    private var ecologyTraits: [TraitSpec] {
        [
            TraitSpec(key: "habitat", displayName: "Habitat", getValue: { $0.habitat }),
            TraitSpec(key: "soil", displayName: "Soil", getValue: { $0.soil }),
            TraitSpec(key: "growthHabit", displayName: "Growth Habit", getValue: { $0.growthHabit }),
        ]
    }

    private func traitsForCategory(_ cat: QuizCategory) -> [TraitSpec] {
        switch cat {
        case .leaves: return leafTraits
        case .flowers: return flowerTraits
        case .fruitsSeeds: return fruitSeedTraits
        case .stemsRoots: return stemRootTraits
        case .ecology: return ecologyTraits
        default: return []
        }
    }

    private var filteredTraitSpecs: [TraitSpec] {
        let specs = traitsForCategory(quizCategory)
        guard let filter = traitFilter else { return specs }
        return specs.filter { $0.key == filter }
    }

    // Family trait definitions
    private var familyLeafTraits: [FamilyTraitSpec] {
        [
            FamilyTraitSpec(key: "leafType", displayName: "Leaf Type", getValue: { $0.leafType }),
            FamilyTraitSpec(key: "leafArrangement", displayName: "Leaf Arrangement", getValue: { $0.leafArrangement }),
            FamilyTraitSpec(key: "leafShape", displayName: "Leaf Shape", getValue: { $0.leafShape }),
            FamilyTraitSpec(key: "leafMargin", displayName: "Leaf Margin", getValue: { $0.leafMargin }),
            FamilyTraitSpec(key: "leafVenation", displayName: "Leaf Venation", getValue: { $0.leafVenation }),
        ]
    }

    private var familyFlowerTraits: [FamilyTraitSpec] {
        [
            FamilyTraitSpec(key: "flowerSymmetry", displayName: "Flower Symmetry", getValue: { $0.flowerSymmetry }),
            FamilyTraitSpec(key: "flowerPetalCount", displayName: "Petal Count", getValue: { $0.flowerPetalCount }),
            FamilyTraitSpec(key: "flowerColor", displayName: "Flower Color", getValue: { $0.flowerColor }),
            FamilyTraitSpec(key: "flowerInflorescence", displayName: "Inflorescence", getValue: { $0.flowerInflorescence }),
            FamilyTraitSpec(key: "flowerOvaryPosition", displayName: "Ovary Position", getValue: { $0.flowerOvaryPosition }),
        ]
    }

    private var familyEcologyTraits: [FamilyTraitSpec] {
        [
            FamilyTraitSpec(key: "growthHabit", displayName: "Growth Habit", getValue: { $0.growthHabit }),
            FamilyTraitSpec(key: "fruitType", displayName: "Fruit Type", getValue: { $0.fruitType }),
            FamilyTraitSpec(key: "habitat", displayName: "Habitat", getValue: { $0.habitat }),
        ]
    }

    // MARK: - Question / Answer Types

    struct QuizQuestion: Identifiable {
        let id = UUID()
        let questionText: String
        let prompt: String
        let promptSubtitle: String?
        let correctAnswer: String
        let options: [String]
        let accentColor: Color
        let explanation: String
        let category: String
        let sourcePlant: Plant?
        let sourceFamily: Family?
        let sourceTerm: BotanyTerm?
        let relatedFamily: Family?

        init(questionText: String, prompt: String, promptSubtitle: String? = nil,
             correctAnswer: String, options: [String], accentColor: Color,
             explanation: String, category: String,
             sourcePlant: Plant? = nil, sourceFamily: Family? = nil,
             sourceTerm: BotanyTerm? = nil, relatedFamily: Family? = nil) {
            self.questionText = questionText
            self.prompt = prompt
            self.promptSubtitle = promptSubtitle
            self.correctAnswer = correctAnswer
            self.options = options
            self.accentColor = accentColor
            self.explanation = explanation
            self.category = category
            self.sourcePlant = sourcePlant
            self.sourceFamily = sourceFamily
            self.sourceTerm = sourceTerm
            self.relatedFamily = relatedFamily
        }
    }

    struct QuizAnswer {
        let question: QuizQuestion
        let selectedAnswer: String
        let isCorrect: Bool
        let outcomeType: OutcomeType

        enum OutcomeType: Equatable {
            case correct, incorrect, revealed, studyMore
        }
    }

    // MARK: - Quiz Data (always full dataset — quiz is ungated)

    private var accessibleTerms: [BotanyTerm] { allTerms }
    private var accessiblePlants: [Plant] { allPlants }
    private var accessibleFamilies: [Family] { allFamilies }

    // MARK: - Term Categories

    private var termCategories: [String] {
        Array(Set(accessibleTerms.map { $0.category })).sorted()
    }

    // MARK: - Sub-filter Options

    private var subFilterOptions: [TraitSpec] {
        traitsForCategory(quizCategory)
    }

    // MARK: - Filtered Pool Count

    private var filteredPool: Int {
        switch quizCategory {
        case .all:
            return poolForTerms + poolForTaxonomy + poolForTraits(leafTraits) +
                   poolForTraits(flowerTraits) + poolForTraits(fruitSeedTraits) +
                   poolForTraits(stemRootTraits) + poolForTraits(ecologyTraits) +
                   poolForFamilies
        case .terms:
            return poolForTerms
        case .taxonomy:
            return poolForTaxonomy
        case .families:
            return poolForFamilies
        case .leaves, .flowers, .fruitsSeeds, .stemsRoots, .ecology:
            return poolForTraits(filteredTraitSpecs)
        }
    }

    private var poolForTerms: Int {
        if let filter = traitFilter, quizCategory == .terms {
            return accessibleTerms.filter { $0.category == filter }.count
        }
        return accessibleTerms.count
    }

    private var poolForTaxonomy: Int {
        accessiblePlants.count * 3
    }

    private func poolForTraits(_ specs: [TraitSpec]) -> Int {
        var count = 0
        for spec in specs {
            let plantsWithValue = accessiblePlants.filter { spec.getValue($0) != nil && !(spec.getValue($0)?.isEmpty ?? true) }
            count += plantsWithValue.count
        }
        return count
    }

    private var poolForFamilies: Int {
        accessiblePlants.count + accessibleFamilies.count * 3
    }

    // MARK: - Quiz State Computed Properties

    private var correctCount: Int {
        answers.filter { $0.outcomeType == .correct }.count
    }

    private var missedAnswers: [QuizAnswer] {
        answers.filter { $0.outcomeType == .incorrect }
    }

    private var revealedCount: Int {
        answers.filter { $0.outcomeType == .revealed }.count
    }

    private var studyMoreCount: Int {
        answers.filter { $0.outcomeType == .studyMore }.count
    }

    private var scorePercent: Double {
        let answered = answers.filter { $0.outcomeType == .correct || $0.outcomeType == .incorrect }.count
        guard answered > 0 else { return 0 }
        return Double(correctCount) / Double(answered)
    }

    private var gradeColor: Color {
        switch scorePercent {
        case 0.9...1.0: return AppColors.success
        case 0.7..<0.9: return AppColors.primaryAmber
        case 0.5..<0.7: return AppColors.warning
        default: return AppColors.error
        }
    }

    private var gradeMessage: String {
        switch scorePercent {
        case 0.9...1.0: return "Excellent!"
        case 0.7..<0.9: return "Great work!"
        case 0.5..<0.7: return "Keep studying!"
        default: return "Room to grow"
        }
    }

    private var elapsedTimeText: String {
        let interval = endTime.timeIntervalSince(startTime)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }

    private var quizProgressFraction: CGFloat {
        guard !questions.isEmpty else { return 0 }
        return CGFloat(currentIndex + 1) / CGFloat(questions.count)
    }

    private var displayQuestionCount: Int {
        questionCount == 0 ? min(filteredPool, 500) : min(questionCount, filteredPool)
    }

    private let countOptions: [(value: Int, label: String)] = [
        (10, "10"), (25, "25"), (50, "50"), (100, "100"), (0, "All")
    ]

    private var canStartQuiz: Bool {
        filteredPool >= 4
    }

    // MARK: - Best Score

    private var bestScoreText: String {
        let key = "quiz_best_\(quizCategory.rawValue)"
        let best = UserDefaults.standard.integer(forKey: key)
        return best > 0 ? "\(best)%" : "—"
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch phase {
            case .setup: setupView
            case .active: activeQuizView
            case .results: resultsView
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $studySheetPlant) { plant in
            NavigationStack {
                PlantDetailView(plant: plant)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { studySheetPlant = nil }
                                .foregroundStyle(AppColors.primaryAmber)
                        }
                    }
            }
        }
        .sheet(item: $studySheetFamily) { family in
            NavigationStack {
                FamilyDetailView(family: family)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { studySheetFamily = nil }
                                .foregroundStyle(AppColors.primaryAmber)
                        }
                    }
            }
        }
        .sheet(item: $studySheetTerm) { term in
            NavigationStack {
                TermDetailView(term: term)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { studySheetTerm = nil }
                                .foregroundStyle(AppColors.primaryAmber)
                        }
                    }
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("Quiz")
                        .font(.cormorant(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(displayQuestionCount) questions \u{00B7} \(quizCategory.rawValue)")
                        .font(AppTypography.inter(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Stats ribbon
                statsRibbon

                // Category pills
                VStack(alignment: .leading, spacing: 10) {
                    Text("CATEGORY")
                        .font(AppTypography.inter(size: 10, weight: .heavy))
                        .tracking(2.0)
                        .foregroundStyle(AppColors.primaryAmber)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(QuizCategory.allCases, id: \.rawValue) { cat in
                                categoryPill(cat)
                            }
                        }
                    }
                }

                // Sub-filter
                if quizCategory == .terms && !termCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FILTER")
                            .font(AppTypography.inter(size: 10, weight: .heavy))
                            .tracking(2.0)
                            .foregroundStyle(AppColors.primaryAmber)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                subFilterChip("All", filterValue: nil)
                                ForEach(termCategories, id: \.self) { cat in
                                    subFilterChip(cat, filterValue: cat)
                                }
                            }
                        }
                    }
                } else if !subFilterOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TRAIT FILTER")
                            .font(AppTypography.inter(size: 10, weight: .heavy))
                            .tracking(2.0)
                            .foregroundStyle(AppColors.primaryAmber)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                subFilterChip("All Traits", filterValue: nil)
                                ForEach(subFilterOptions, id: \.key) { spec in
                                    subFilterChip(spec.displayName, filterValue: spec.key)
                                }
                            }
                        }
                    }
                }

                // Questions
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUESTIONS")
                        .font(AppTypography.inter(size: 10, weight: .heavy))
                        .tracking(2.0)
                        .foregroundStyle(AppColors.primaryAmber)

                    HStack(spacing: 8) {
                        ForEach(countOptions, id: \.value) { option in
                            countPill(option.value, label: option.label)
                        }
                    }
                }

                // Start button
                Button {
                    startQuiz()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(AppTypography.inter(size: 14))
                        Text(canStartQuiz ? "Start Quiz" : "Not Enough Data")
                            .font(AppTypography.inter(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(canStartQuiz ? quizCategory.color : AppColors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canStartQuiz ? quizCategory.color.opacity(0.12) : AppColors.textMuted.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.button).stroke(canStartQuiz ? quizCategory.color.opacity(0.4) : AppColors.border, lineWidth: 0.5))
                }
                .disabled(!canStartQuiz)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Stats Ribbon

    private var statsRibbon: some View {
        HStack(spacing: 0) {
            ribbonStat(value: filteredPool > 100 ? "100+" : "\(filteredPool)", label: "Available")
            Rectangle()
                .fill(AppColors.border)
                .frame(width: 0.5, height: 24)
            ribbonStat(value: displayQuestionCount > 100 ? "100+" : "\(displayQuestionCount)", label: "Per Quiz")
        }
        .padding(.vertical, 8)
    }

    private func ribbonStat(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(AppTypography.inter(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.primaryAmber)
            Text(label)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Pill

    private func categoryPill(_ category: QuizCategory) -> some View {
        let isSelected = quizCategory == category
        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                quizCategory = category
                traitFilter = nil
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: category.icon)
                    .font(AppTypography.inter(size: 11))
                Text(category.rawValue)
                    .font(AppTypography.inter(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? category.color : AppColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? category.color.opacity(0.15) : AppColors.cardElevated)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? category.color.opacity(0.4) : Color.clear, lineWidth: 0.5))
        }
    }

    // MARK: - Sub-filter Chip

    private func subFilterChip(_ label: String, filterValue: String?) -> some View {
        let isSelected = traitFilter == filterValue
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                traitFilter = filterValue
            }
        } label: {
            Text(label)
                .font(AppTypography.inter(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? quizCategory.color : AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? quizCategory.color.opacity(0.15) : AppColors.cardElevated)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? quizCategory.color.opacity(0.4) : Color.clear, lineWidth: 0.5))
        }
    }

    // MARK: - Count Pill

    private func countPill(_ value: Int, label: String) -> some View {
        let isSelected = questionCount == value
        return Button {
            questionCount = value
        } label: {
            Text(label)
                .font(AppTypography.inter(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? quizCategory.color : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? quizCategory.color.opacity(0.12) : AppColors.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.button).stroke(isSelected ? quizCategory.color.opacity(0.4) : Color.clear, lineWidth: 0.5))
        }
    }

    // MARK: - Active Quiz View

    private var activeQuizView: some View {
        VStack(spacing: 0) {
            quizProgressHeader

            // Study More banner
            if showStudyMoreBanner {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 11))
                    Text("Reviewing \(studyMoreBannerCount) flagged question\(studyMoreBannerCount == 1 ? "" : "s")...")
                        .font(AppTypography.inter(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppColors.primaryAmber)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(AppColors.primaryAmber.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 0.5))
                .padding(.horizontal, 20).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView(showsIndicators: false) {
                if currentIndex < questions.count {
                    let question = questions[currentIndex]

                    VStack(alignment: .leading, spacing: 16) {
                        // Question text
                        Text(question.questionText)
                            .font(AppTypography.inter(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.top, 12)

                        // Prompt (species/term name)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(question.prompt)
                                .font(question.category == "Terms"
                                    ? AppTypography.bodyText
                                    : AppTypography.headerTitle)
                                .foregroundStyle(AppColors.textPrimary)

                            if let sub = question.promptSubtitle {
                                Text(sub)
                                    .font(.system(size: 13, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        // Options
                        VStack(spacing: 8) {
                            ForEach(Array(question.options.enumerated()), id: \.offset) { idx, option in
                                optionButton(option, index: idx, question: question)
                            }
                        }
                        .padding(.top, 4)

                        // Study More + Reveal (only when unanswered)
                        if case .unanswered = outcome {
                            HStack(spacing: 10) {
                                Button {
                                    // Open the most relevant detail sheet, then queue
                                    if question.category == "Terms", let term = question.sourceTerm {
                                        studySheetTerm = term
                                    } else if question.category == "Families", let family = question.sourceFamily {
                                        studySheetFamily = family
                                    } else if let plant = question.sourcePlant {
                                        studySheetPlant = plant
                                    } else if let family = question.sourceFamily ?? question.relatedFamily {
                                        studySheetFamily = family
                                    } else if let term = question.sourceTerm {
                                        studySheetTerm = term
                                    }
                                    studyMoreAction(question: question)
                                } label: {
                                    Text("Study")
                                        .font(AppTypography.inter(size: 11, weight: .heavy))
                                        .tracking(0.5)
                                    .foregroundStyle(AppColors.primaryAmber)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppColors.primaryAmber.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                                    .overlay(RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 0.5))
                                }

                                Button { revealAction(question: question) } label: {
                                    Text("Reveal")
                                        .font(AppTypography.inter(size: 11, weight: .heavy))
                                        .tracking(0.5)
                                    .foregroundStyle(AppColors.primaryAmber)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppColors.primaryAmber.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                                    .overlay(RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 0.5))
                                }
                            }
                            .padding(.top, 4)
                        }

                        // Explanation (shown when committed)
                        if outcome.isCommitted {
                            explanationCard(question)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Next button
                        if outcome.isCommitted {
                            let nextText = currentIndex >= questions.count - 1
                                ? (studyMoreQueue.isEmpty ? "See Results" : "Review \(studyMoreQueue.count) Flagged →")
                                : "Next Question →"
                            Button {
                                withAnimation(.easeOut(duration: 0.25)) { nextQuestion() }
                            } label: {
                                Text(nextText)
                                    .font(AppTypography.inter(size: 14, weight: .semibold))
                                    .foregroundStyle(quizCategory.color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(quizCategory.color.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                                    .overlay(RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(quizCategory.color.opacity(0.4), lineWidth: 0.5))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width > 100 && outcome.isCommitted {
                        withAnimation { nextQuestion() }
                    }
                }
        )
    }

    // MARK: - Progress Header

    private var quizProgressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(currentIndex + 1) of \(questions.count)")
                    .font(AppTypography.inter(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Text("\(correctCount) correct")
                    .font(AppTypography.inter(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.success)
            }

            // Segmented progress bar
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    ForEach(0..<questions.count, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(segmentColor(for: idx))
                            .frame(height: 3)
                    }
                }
                .frame(width: geo.size.width)
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
    }

    private func segmentColor(for index: Int) -> Color {
        guard index < answers.count else {
            return index == currentIndex
                ? quizCategory.color.opacity(0.4)
                : AppColors.cardElevated
        }
        switch answers[index].outcomeType {
        case .correct: return AppColors.success
        case .incorrect: return AppColors.error
        case .revealed: return AppColors.primaryAmber.opacity(0.6)
        case .studyMore: return AppColors.textMuted.opacity(0.4)
        }
    }

    // MARK: - Explanation Card

    private func explanationCard(_ question: QuizQuestion) -> some View {
        let headerIcon: String
        let headerText: String
        let headerColor: Color
        switch outcome {
        case .correct:
            headerIcon = "checkmark.circle.fill"; headerText = "Correct"; headerColor = AppColors.success
        case .incorrect:
            headerIcon = "xmark.circle.fill"; headerText = "Incorrect"; headerColor = AppColors.error
        case .revealed:
            headerIcon = "eye.circle.fill"; headerText = "Answer"; headerColor = AppColors.primaryAmber
        default:
            headerIcon = "info.circle.fill"; headerText = "Answer"; headerColor = AppColors.textSecondary
        }

        let hasStudyLinks = question.sourcePlant != nil || question.sourceFamily != nil
            || question.sourceTerm != nil || question.relatedFamily != nil

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: headerIcon)
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(headerColor)
                Text(headerText)
                    .font(AppTypography.inter(size: 14, weight: .semibold))
                    .foregroundStyle(headerColor)
            }

            if case .incorrect = outcome {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.success)
                    Text("Answer: \(question.correctAnswer)")
                        .font(AppTypography.inter(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                }
            }

            Text(question.explanation)
                .font(AppTypography.inter(size: 12, weight: .regular))
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)

            if hasStudyLinks {
                Divider().background(AppColors.border).padding(.vertical, 2)

                Text("STUDY")
                    .font(AppTypography.inter(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(AppColors.primaryAmber)

                VStack(alignment: .leading, spacing: 6) {
                    if let plant = question.sourcePlant {
                        Button { studySheetPlant = plant } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "leaf.fill").font(.system(size: 10))
                                Text("Study \(plant.titleCasedCommonName)")
                                    .font(AppTypography.inter(size: 12, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 9))
                            }
                            .foregroundStyle(AppColors.success)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(AppColors.success.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    let displayFamily = question.sourceFamily ?? question.relatedFamily
                    if let family = displayFamily {
                        let familyName = family.familyEnglish.isEmpty ? family.familyLatin : family.familyEnglish
                        Button { studySheetFamily = family } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.3x3.fill").font(.system(size: 10))
                                Text("Study \(familyName)")
                                    .font(AppTypography.inter(size: 12, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 9))
                            }
                            .foregroundStyle(AppColors.primaryAmber)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(AppColors.primaryAmber.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if let term = question.sourceTerm {
                        Button { studySheetTerm = term } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "text.book.closed.fill").font(.system(size: 10))
                                Text("Study \"\(term.term)\"")
                                    .font(AppTypography.inter(size: 12, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 9))
                            }
                            .foregroundStyle(Color.purpleSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.purpleSecondary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Option Button

    private func optionButton(_ option: String, index: Int, question: QuizQuestion) -> some View {
        let letters = ["A", "B", "C", "D"]
        let isSelected = outcome.selectedAnswer == option
        let isCorrectOption = option == question.correctAnswer
        let showCorrect = outcome.isCommitted && isCorrectOption
        let showIncorrect = outcome.isCommitted && isSelected && !isCorrectOption

        return Button {
            if !outcome.isCommitted {
                selectAnswer(option, for: question)
            }
        } label: {
            HStack(spacing: 12) {
                // Letter circle
                Text(index < letters.count ? letters[index] : "")
                    .font(AppTypography.inter(size: 12, weight: .bold))
                    .foregroundStyle(
                        showCorrect ? .white :
                        showIncorrect ? .white :
                        isSelected ? .white :
                        AppColors.textSecondary
                    )
                    .frame(width: 28, height: 28)
                    .background(
                        showCorrect ? AppColors.success :
                        showIncorrect ? AppColors.error :
                        isSelected ? quizCategory.color :
                        AppColors.cardElevated
                    )
                    .clipShape(Circle())

                // Answer text
                Text(option)
                    .font(AppTypography.inter(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Feedback icon
                if showCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.inter(size: 16))
                        .foregroundStyle(AppColors.success)
                } else if showIncorrect {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.inter(size: 16))
                        .foregroundStyle(AppColors.error)
                }
            }
            .padding(12)
            .background(
                showCorrect ? AppColors.success.opacity(0.1) :
                showIncorrect ? AppColors.error.opacity(0.1) :
                AppColors.cardBackground
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(
                        showCorrect ? AppColors.success.opacity(0.5) :
                        showIncorrect ? AppColors.error.opacity(0.5) :
                        isSelected ? quizCategory.color.opacity(0.5) :
                        AppColors.border,
                        lineWidth: showCorrect || showIncorrect ? 1.0 : 0.5
                    )
            )
        }
        .disabled(outcome.isCommitted)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Score ring
                scoreRing

                // Grade
                Text(gradeMessage)
                    .font(.cormorant(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                let answeredCount = correctCount + missedAnswers.count
                Text(answeredCount > 0
                     ? "\(correctCount) of \(answeredCount) answered correctly"
                     : "No questions answered")
                    .font(AppTypography.inter(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)

                // Outcome breakdown
                HStack(spacing: 16) {
                    Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    Label("\(missedAnswers.count)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(AppColors.error)
                    if revealedCount > 0 {
                        Label("\(revealedCount)", systemImage: "eye.fill")
                            .foregroundStyle(AppColors.primaryAmber)
                    }
                    if studyMoreCount > 0 {
                        Label("\(studyMoreCount)", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
                .font(AppTypography.inter(size: 13, weight: .semibold))

                // Stats row
                HStack(spacing: 12) {
                    resultStatCard(icon: "clock.fill", value: elapsedTimeText, label: "Time", color: AppColors.primaryAmber)
                    resultStatCard(icon: "checkmark.circle.fill", value: "\(correctCount)", label: "Correct", color: AppColors.success)
                    resultStatCard(icon: "xmark.circle.fill", value: "\(missedAnswers.count)", label: "Missed", color: AppColors.error)
                }

                // XP earned
                if sessionManager.xpEarned > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(AppTypography.inter(size: 12))
                            .foregroundStyle(AppColors.primaryAmber)
                        Text("+\(formatXP(sessionManager.xpEarned)) XP earned")
                            .font(AppTypography.inter(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.primaryAmber)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.primaryAmber.opacity(0.1))
                    .clipShape(Capsule())
                }

                // Missed questions review
                if !missedAnswers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("REVIEW MISSED")
                            .font(AppTypography.inter(size: 10, weight: .heavy))
                            .tracking(2.0)
                            .foregroundStyle(AppColors.primaryAmber)

                        ForEach(Array(missedAnswers.enumerated()), id: \.offset) { _, answer in
                            resultRow(answer)
                        }
                    }
                }

                // Action buttons
                VStack(spacing: 10) {
                    if !missedAnswers.isEmpty {
                        Button {
                            reviewMistakes()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(AppTypography.inter(size: 12))
                                Text("Quiz Missed Questions")
                                    .font(AppTypography.inter(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(quizCategory.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(quizCategory.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.button).stroke(quizCategory.color.opacity(0.4), lineWidth: 0.5))
                        }
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            phase = .setup
                        }
                    } label: {
                        Text("New Quiz")
                            .font(AppTypography.inter(size: 14, weight: .semibold))
                            .foregroundStyle(quizCategory.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(quizCategory.color.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(AppColors.cardElevated, lineWidth: 8)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: scorePercent)
                .stroke(gradeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            Text("\(Int(scorePercent * 100))%")
                .font(AppTypography.inter(size: 28, weight: .bold))
                .foregroundStyle(gradeColor)
        }
    }

    private func resultStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(AppTypography.inter(size: 16, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            Text(label)
                .font(AppTypography.inter(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func resultRow(_ answer: QuizAnswer) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(answer.question.prompt)
                .font(AppTypography.inter(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppTypography.inter(size: 10))
                    .foregroundStyle(AppColors.error)
                Text(answer.selectedAnswer)
                    .font(AppTypography.inter(size: 11))
                    .foregroundStyle(AppColors.error)
                    .strikethrough()

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(AppTypography.inter(size: 10))
                    .foregroundStyle(AppColors.success)
                Text(answer.question.correctAnswer)
                    .font(AppTypography.inter(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.success)
            }
        }
        .padding(10)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Generate Questions Router

    private func generateQuestions(count: Int) -> [QuizQuestion] {
        switch quizCategory {
        case .all:
            return generateAllQuestions(count: count)
        case .taxonomy:
            return generateTaxonomyQuestions(count: count)
        case .leaves:
            return generateTraitQuestions(specs: filteredTraitSpecs.isEmpty ? leafTraits : filteredTraitSpecs, count: count, color: QuizCategory.leaves.color, categoryLabel: "Leaves")
        case .flowers:
            return generateTraitQuestions(specs: filteredTraitSpecs.isEmpty ? flowerTraits : filteredTraitSpecs, count: count, color: QuizCategory.flowers.color, categoryLabel: "Flowers")
        case .fruitsSeeds:
            return generateTraitQuestions(specs: filteredTraitSpecs.isEmpty ? fruitSeedTraits : filteredTraitSpecs, count: count, color: QuizCategory.fruitsSeeds.color, categoryLabel: "Fruits & Seeds")
        case .stemsRoots:
            return generateTraitQuestions(specs: filteredTraitSpecs.isEmpty ? stemRootTraits : filteredTraitSpecs, count: count, color: QuizCategory.stemsRoots.color, categoryLabel: "Stems & Roots")
        case .ecology:
            return generateTraitQuestions(specs: filteredTraitSpecs.isEmpty ? ecologyTraits : filteredTraitSpecs, count: count, color: QuizCategory.ecology.color, categoryLabel: "Ecology")
        case .terms:
            return generateTermQuestions(count: count)
        case .families:
            return generateFamilyQuestions(count: count)
        }
    }

    // MARK: - Generate All (Proportional Mix)

    private func generateAllQuestions(count: Int) -> [QuizQuestion] {
        let perCategory = max(count / 8, 2)
        let extra = count - (perCategory * 8)

        var all: [QuizQuestion] = []
        all.append(contentsOf: generateTaxonomyQuestions(count: perCategory))
        all.append(contentsOf: generateTraitQuestions(specs: leafTraits, count: perCategory, color: QuizCategory.leaves.color, categoryLabel: "Leaves"))
        all.append(contentsOf: generateTraitQuestions(specs: flowerTraits, count: perCategory, color: QuizCategory.flowers.color, categoryLabel: "Flowers"))
        all.append(contentsOf: generateTraitQuestions(specs: fruitSeedTraits, count: perCategory, color: QuizCategory.fruitsSeeds.color, categoryLabel: "Fruits & Seeds"))
        all.append(contentsOf: generateTraitQuestions(specs: stemRootTraits, count: perCategory, color: QuizCategory.stemsRoots.color, categoryLabel: "Stems & Roots"))
        all.append(contentsOf: generateTraitQuestions(specs: ecologyTraits, count: perCategory, color: QuizCategory.ecology.color, categoryLabel: "Ecology"))
        all.append(contentsOf: generateTermQuestions(count: perCategory))
        all.append(contentsOf: generateFamilyQuestions(count: perCategory + extra))

        all.shuffle()
        return Array(all.prefix(count))
    }

    // MARK: - Trait Question Generator

    private func generateTraitQuestions(specs: [TraitSpec], count: Int, color: Color, categoryLabel: String) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let plants = accessiblePlants

        struct SpecPool {
            let spec: TraitSpec
            let plantsWithValue: [(plant: Plant, value: String)]
            let allValues: [String]
        }

        let pools: [SpecPool] = specs.compactMap { spec in
            let pairs = plants.compactMap { plant -> (plant: Plant, value: String)? in
                guard let v = spec.getValue(plant), !v.isEmpty else { return nil }
                return (plant, v)
            }
            guard pairs.count >= 4 else { return nil }
            let allValues = Array(Set(pairs.map { $0.value }))
            guard allValues.count >= 2 else { return nil }
            return SpecPool(spec: spec, plantsWithValue: pairs, allValues: allValues)
        }

        guard !pools.isEmpty else { return [] }

        let formatA_phrasings = [
            { (trait: String, name: String) in "What is the \(trait.lowercased()) of this species?" },
            { (trait: String, name: String) in "Identify the \(trait.lowercased()) for this plant" },
            { (trait: String, name: String) in "Which \(trait.lowercased()) describes this species?" },
            { (trait: String, name: String) in "Select the correct \(trait.lowercased())" },
        ]

        let formatB_phrasings = [
            { (trait: String, value: String) in "Which species has \(value.lowercased()) as its \(trait.lowercased())?" },
            { (trait: String, value: String) in "Select the species with \(trait.lowercased()): \(value)" },
            { (trait: String, value: String) in "Which plant is characterized by \(value.lowercased())?" },
        ]

        var generated = 0
        var poolIndex = 0
        var usedPairs: Set<String> = []

        while generated < count {
            let pool = pools[poolIndex % pools.count]
            poolIndex += 1

            let useFormatA = Bool.random()

            if useFormatA {
                let candidates = pool.plantsWithValue.filter { !usedPairs.contains("\($0.plant.scientificName)_\(pool.spec.key)_A") }
                guard let pick = candidates.randomElement() else { continue }
                usedPairs.insert("\(pick.plant.scientificName)_\(pool.spec.key)_A")

                let correctValue = pick.value
                var distractors = pool.allValues.filter { $0 != correctValue }.shuffled()
                distractors = Array(distractors.prefix(3))
                guard distractors.count == 3 else { continue }

                let options = ([correctValue] + distractors).shuffled()
                let phrasing = formatA_phrasings.randomElement()!(pool.spec.displayName, pick.plant.titleCasedCommonName)
                let explanation = "\(pick.plant.titleCasedCommonName) (\(pick.plant.scientificName)) of the \(pick.plant.familyLatin) family has \(pool.spec.displayName.lowercased()): \(correctValue)."
                let relatedFam = accessibleFamilies.first(where: { $0.familyLatin == pick.plant.familyLatin })

                questions.append(QuizQuestion(
                    questionText: phrasing,
                    prompt: pick.plant.titleCasedCommonName,
                    promptSubtitle: pick.plant.scientificName,
                    correctAnswer: correctValue,
                    options: options,
                    accentColor: color,
                    explanation: explanation,
                    category: categoryLabel,
                    sourcePlant: pick.plant,
                    relatedFamily: relatedFam
                ))
                generated += 1

            } else {
                guard pool.allValues.count >= 2 else { continue }
                let targetValue = pool.allValues.randomElement()!
                let matchingPlants = pool.plantsWithValue.filter { $0.value == targetValue }
                let nonMatchingPlants = pool.plantsWithValue.filter { $0.value != targetValue }

                guard let correctPick = matchingPlants.randomElement(),
                      nonMatchingPlants.count >= 3 else { continue }

                let uniqueKey = "\(correctPick.plant.scientificName)_\(pool.spec.key)_B_\(targetValue)"
                guard !usedPairs.contains(uniqueKey) else { continue }
                usedPairs.insert(uniqueKey)

                let distractorPlants = Array(nonMatchingPlants.shuffled().prefix(3))
                let options = ([correctPick.plant.scientificName] + distractorPlants.map { $0.plant.scientificName }).shuffled()
                let phrasing = formatB_phrasings.randomElement()!(pool.spec.displayName, targetValue)
                let explanation = "\(correctPick.plant.titleCasedCommonName) (\(correctPick.plant.scientificName)) has \(pool.spec.displayName.lowercased()): \(targetValue). Family: \(correctPick.plant.familyLatin)."
                let relatedFam = accessibleFamilies.first(where: { $0.familyLatin == correctPick.plant.familyLatin })

                questions.append(QuizQuestion(
                    questionText: phrasing,
                    prompt: targetValue,
                    promptSubtitle: pool.spec.displayName,
                    correctAnswer: correctPick.plant.scientificName,
                    options: options,
                    accentColor: color,
                    explanation: explanation,
                    category: categoryLabel,
                    sourcePlant: correctPick.plant,
                    relatedFamily: relatedFam
                ))
                generated += 1
            }

            if poolIndex > count * 10 { break }
        }

        return questions
    }

    // MARK: - Taxonomy Questions

    private func generateTaxonomyQuestions(count: Int) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let plants = accessiblePlants.shuffled()
        let color = QuizCategory.taxonomy.color

        var subType = 0
        var usedPlants: Set<String> = []

        for plant in plants {
            guard questions.count < count else { break }
            let key = "\(plant.scientificName)_\(subType)"
            guard !usedPlants.contains(key) else { continue }
            usedPlants.insert(key)

            switch subType % 3 {
            case 0:
                var distractors = plants.filter { $0.scientificName != plant.scientificName }
                    .shuffled().prefix(3).map { $0.scientificName }
                guard distractors.count == 3 else { subType += 1; continue }
                let options = ([plant.scientificName] + distractors).shuffled()
                let relatedFam = accessibleFamilies.first(where: { $0.familyLatin == plant.familyLatin })

                questions.append(QuizQuestion(
                    questionText: "What is the scientific name of this species?",
                    prompt: plant.titleCasedCommonName,
                    promptSubtitle: nil,
                    correctAnswer: plant.scientificName,
                    options: options,
                    accentColor: color,
                    explanation: "\(plant.titleCasedCommonName) is scientifically known as \(plant.scientificName), belonging to the \(plant.familyLatin) family.",
                    category: "Taxonomy",
                    sourcePlant: plant,
                    relatedFamily: relatedFam
                ))

            case 1:
                var distractors = plants.filter { $0.commonName != plant.commonName }
                    .shuffled().prefix(3).map { $0.titleCasedCommonName }
                guard distractors.count == 3 else { subType += 1; continue }
                let options = ([plant.titleCasedCommonName] + distractors).shuffled()
                let relatedFam = accessibleFamilies.first(where: { $0.familyLatin == plant.familyLatin })

                questions.append(QuizQuestion(
                    questionText: "What is the common name of this species?",
                    prompt: plant.scientificName,
                    promptSubtitle: nil,
                    correctAnswer: plant.titleCasedCommonName,
                    options: options,
                    accentColor: color,
                    explanation: "\(plant.scientificName) is commonly known as \(plant.titleCasedCommonName). Family: \(plant.familyLatin).",
                    category: "Taxonomy",
                    sourcePlant: plant,
                    relatedFamily: relatedFam
                ))

            case 2:
                let families = Array(Set(accessiblePlants.map { $0.familyLatin }))
                var distractors = families.filter { $0 != plant.familyLatin }.shuffled()
                distractors = Array(distractors.prefix(3))
                guard distractors.count == 3 else { subType += 1; continue }
                let options = ([plant.familyLatin] + distractors).shuffled()
                let sourceFamily = accessibleFamilies.first(where: { $0.familyLatin == plant.familyLatin })
                let familyEnglish = sourceFamily?.familyEnglish ?? ""

                questions.append(QuizQuestion(
                    questionText: "Which family does this species belong to?",
                    prompt: plant.titleCasedCommonName,
                    promptSubtitle: plant.scientificName,
                    correctAnswer: plant.familyLatin,
                    options: options,
                    accentColor: color,
                    explanation: "\(plant.titleCasedCommonName) (\(plant.scientificName)) belongs to \(plant.familyLatin)\(familyEnglish.isEmpty ? "" : " (\(familyEnglish))").",
                    category: "Taxonomy",
                    sourcePlant: plant,
                    sourceFamily: sourceFamily
                ))

            default: break
            }

            subType += 1
        }

        return questions
    }

    // MARK: - Term Questions

    private func generateTermQuestions(count: Int) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let color = QuizCategory.terms.color

        var terms = accessibleTerms
        if let filter = traitFilter, quizCategory == .terms {
            terms = terms.filter { $0.category == filter }
        }

        let shuffled = terms.shuffled()

        for term in shuffled {
            guard questions.count < count else { break }

            let sameCategory = terms.filter { $0.term != term.term && $0.category == term.category }
            let otherTerms = terms.filter { $0.term != term.term }

            var distractors = sameCategory.shuffled().prefix(3).map { $0.term }
            if distractors.count < 3 {
                let needed = 3 - distractors.count
                let extras = otherTerms.filter { !distractors.contains($0.term) }
                    .shuffled().prefix(needed).map { $0.term }
                distractors.append(contentsOf: extras)
            }
            guard distractors.count == 3 else { continue }

            let options = ([term.term] + distractors).shuffled()

            questions.append(QuizQuestion(
                questionText: "Which term matches this definition?",
                prompt: term.descriptionShort,
                promptSubtitle: term.category,
                correctAnswer: term.term,
                options: options,
                accentColor: color,
                explanation: "\"\(term.term)\"\(term.category.isEmpty ? "" : " (\(term.category))"): \(term.descriptionShort)",
                category: "Terms",
                sourceTerm: term
            ))
        }

        return questions
    }

    // MARK: - Family Questions

    private func generateFamilyQuestions(count: Int) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        let color = QuizCategory.families.color
        let families = accessibleFamilies
        let plants = accessiblePlants

        let half = count / 2

        // Part 1: Species → Family identification
        let shuffledPlants = plants.shuffled()
        for plant in shuffledPlants {
            guard questions.count < half else { break }

            let allFamilyNames = Array(Set(plants.map { $0.familyLatin }))
            var distractors = allFamilyNames.filter { $0 != plant.familyLatin }.shuffled()
            distractors = Array(distractors.prefix(3))
            guard distractors.count == 3 else { continue }

            let options = ([plant.familyLatin] + distractors).shuffled()
            let matchedFamily = families.first(where: { $0.familyLatin == plant.familyLatin })
            let familyEnglish = matchedFamily?.familyEnglish ?? ""

            questions.append(QuizQuestion(
                questionText: "Which family does this species belong to?",
                prompt: plant.titleCasedCommonName,
                promptSubtitle: plant.scientificName,
                correctAnswer: plant.familyLatin,
                options: options,
                accentColor: color,
                explanation: "\(plant.titleCasedCommonName) belongs to \(plant.familyLatin)\(familyEnglish.isEmpty ? "" : " (\(familyEnglish))"). Genus: \(plant.genus).",
                category: "Families",
                sourcePlant: plant,
                sourceFamily: matchedFamily
            ))
        }

        // Part 2: Family trait questions
        let familyTraitSets: [(specs: [FamilyTraitSpec], label: String)] = [
            (familyLeafTraits, "leaf"),
            (familyFlowerTraits, "flower"),
            (familyEcologyTraits, "ecology"),
        ]

        let remaining = count - questions.count

        for _ in 0..<remaining {
            guard let traitSet = familyTraitSets.randomElement(),
                  let spec = traitSet.specs.randomElement() else { continue }

            let familiesWithValue = families.compactMap { fam -> (family: Family, value: String)? in
                guard let v = spec.getValue(fam), !v.isEmpty else { return nil }
                return (fam, v)
            }
            guard familiesWithValue.count >= 4 else { continue }

            let allValues = Array(Set(familiesWithValue.map { $0.value }))
            guard allValues.count >= 2 else { continue }

            if Bool.random() {
                // Format A: What is the [trait] of [family]?
                guard let pick = familiesWithValue.randomElement() else { continue }
                var distractors = allValues.filter { $0 != pick.value }.shuffled()
                distractors = Array(distractors.prefix(3))
                guard distractors.count == 3 else { continue }

                let options = ([pick.value] + distractors).shuffled()

                questions.append(QuizQuestion(
                    questionText: "What is the typical \(spec.displayName.lowercased()) for this family?",
                    prompt: pick.family.familyLatin,
                    promptSubtitle: pick.family.familyEnglish,
                    correctAnswer: pick.value,
                    options: options,
                    accentColor: color,
                    explanation: "\(pick.family.familyLatin) (\(pick.family.familyEnglish)) typically has \(spec.displayName.lowercased()): \(pick.value). Key genera: \(pick.family.genera).",
                    category: "Families",
                    sourceFamily: pick.family
                ))
            } else {
                // Format B: Which family has [trait value]?
                let targetValue = allValues.randomElement()!
                let matching = familiesWithValue.filter { $0.value == targetValue }
                let nonMatching = familiesWithValue.filter { $0.value != targetValue }

                guard let correctPick = matching.randomElement(),
                      nonMatching.count >= 3 else { continue }

                let distractorFamilies = Array(nonMatching.shuffled().prefix(3))
                let options = ([correctPick.family.familyLatin] + distractorFamilies.map { $0.family.familyLatin }).shuffled()

                questions.append(QuizQuestion(
                    questionText: "Which family typically has \(spec.displayName.lowercased()): \(targetValue)?",
                    prompt: targetValue,
                    promptSubtitle: spec.displayName,
                    correctAnswer: correctPick.family.familyLatin,
                    options: options,
                    accentColor: color,
                    explanation: "\(correctPick.family.familyLatin) (\(correctPick.family.familyEnglish)) has \(spec.displayName.lowercased()): \(targetValue). Key genera: \(correctPick.family.genera).",
                    category: "Families",
                    sourceFamily: correctPick.family
                ))
            }
        }

        return questions
    }

    // MARK: - Quiz Logic

    private func startQuiz() {
        guard canStartQuiz else { return }

        let count = displayQuestionCount
        var generated = generateQuestions(count: count)

        generated.shuffle()
        questions = Array(generated.prefix(count))
        currentIndex = 0
        outcome = .unanswered
        answers = []
        studyMoreQueue = []
        showStudyMoreBanner = false
        studyMoreBannerCount = 0
        startTime = .now
        sessionManager = StudySessionManager()

        withAnimation(.easeOut(duration: 0.3)) {
            phase = .active
        }
    }

    private func selectAnswer(_ answer: String, for question: QuizQuestion) {
        let isCorrect = answer == question.correctAnswer
        let outcomeType: QuizAnswer.OutcomeType = isCorrect ? .correct : .incorrect
        answers.append(QuizAnswer(question: question, selectedAnswer: answer, isCorrect: isCorrect, outcomeType: outcomeType))
        sessionManager.recordCardReview(mastered: isCorrect, modelContext: modelContext)

        withAnimation(.easeOut(duration: 0.3)) {
            outcome = isCorrect ? .correct(answer: answer) : .incorrect(answer: answer)
        }
    }

    private func studyMoreAction(question: QuizQuestion) {
        studyMoreQueue.append(question)
        answers.append(QuizAnswer(question: question, selectedAnswer: "", isCorrect: false, outcomeType: .studyMore))
        withAnimation(.easeOut(duration: 0.25)) { nextQuestion() }
    }

    private func revealAction(question: QuizQuestion) {
        answers.append(QuizAnswer(question: question, selectedAnswer: question.correctAnswer, isCorrect: false, outcomeType: .revealed))
        withAnimation(.easeOut(duration: 0.3)) {
            outcome = .revealed
        }
    }

    private func finishQuiz() {
        endTime = .now
        sessionManager.completeDeck(modelContext: modelContext)

        let percent = Int(scorePercent * 100)
        let key = "quiz_best_\(quizCategory.rawValue)"
        let currentBest = UserDefaults.standard.integer(forKey: key)
        if percent > currentBest {
            UserDefaults.standard.set(percent, forKey: key)
        }

        withAnimation(.easeOut(duration: 0.3)) {
            phase = .results
        }
    }

    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            outcome = .unanswered
        } else if !studyMoreQueue.isEmpty {
            studyMoreBannerCount = studyMoreQueue.count
            questions.append(contentsOf: studyMoreQueue.shuffled())
            studyMoreQueue = []
            currentIndex += 1
            outcome = .unanswered
            withAnimation(.easeOut(duration: 0.3)) { showStudyMoreBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) { showStudyMoreBanner = false }
            }
        } else {
            finishQuiz()
        }
    }

    private func reviewMistakes() {
        let missedQuestions = missedAnswers.map { $0.question }
        guard !missedQuestions.isEmpty else { return }

        questions = missedQuestions.shuffled()
        currentIndex = 0
        outcome = .unanswered
        answers = []
        studyMoreQueue = []
        showStudyMoreBanner = false
        studyMoreBannerCount = 0
        startTime = .now
        sessionManager = StudySessionManager()

        withAnimation(.easeOut(duration: 0.3)) {
            phase = .active
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QuizView()
            .environmentObject(StoreManager())
    }
    .preferredColorScheme(.dark)
}
