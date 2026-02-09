import SwiftUI
import SwiftData

// MARK: - Plant Organ

enum PlantOrgan: String, CaseIterable, Identifiable {
    case flower = "Flower"
    case leaf = "Leaf"
    case fruit = "Fruit"
    case bark = "Bark"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .flower: return "camera.macro"
        case .leaf: return "leaf.fill"
        case .fruit: return "apple.logo"
        case .bark: return "tree.fill"
        }
    }

    /// Trait questions for each organ, mapped to the Plant model's property names.
    var traitQuestions: [TraitQuestion] {
        switch self {
        case .leaf:
            return [
                TraitQuestion(title: "Leaf Type", category: "Leaf_Type", keyPath: \.leafType),
                TraitQuestion(title: "Leaf Shape", category: "Leaf_Shape", keyPath: \.leafShape),
                TraitQuestion(title: "Leaf Margin", category: "Leaf_Margin", keyPath: \.leafMargin),
                TraitQuestion(title: "Leaf Arrangement", category: "Leaf_Arrangement", keyPath: \.leafArrangement),
                TraitQuestion(title: "Leaf Venation", category: "Leaf_Venation", keyPath: \.leafVenation),
                TraitQuestion(title: "Leaf Texture", category: "Leaf_Texture", keyPath: \.leafTexture)
            ]
        case .flower:
            return [
                TraitQuestion(title: "Flower Symmetry", category: "Flower_Symmetry", keyPath: \.flowerSymmetry),
                TraitQuestion(title: "Flower Color", category: "Flower_Color", keyPath: \.flowerColor),
                TraitQuestion(title: "Petal Count", category: "Flower_Petal Count", keyPath: \.flowerPetalCount),
                TraitQuestion(title: "Inflorescence", category: "Flower_Inflorescence", keyPath: \.flowerInflorescence),
                TraitQuestion(title: "Flower Position", category: "Flower_Position", keyPath: \.flowerPosition)
            ]
        case .fruit:
            return [
                TraitQuestion(title: "Fruit Type", category: "Fruit_Type", keyPath: \.fruitType),
                TraitQuestion(title: "Seed Trait", category: "Fruit_Seed Trait", keyPath: \.fruitSeedTrait)
            ]
        case .bark:
            return [
                TraitQuestion(title: "Stem Habit", category: "Stem_Habit", keyPath: \.stemHabit),
                TraitQuestion(title: "Stem Structure", category: "Stem_Structure", keyPath: \.stemStructure)
            ]
        }
    }
}

// MARK: - Trait Question

struct TraitQuestion: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let keyPath: KeyPath<Plant, String?>
}

// MARK: - Plant Match Result

struct PlantMatchResult: Identifiable {
    let id = UUID()
    let plant: Plant
    let matchPercentage: Double
    let matchedTraits: Int
    let totalTraits: Int
}

// MARK: - ObserveView

struct ObserveView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query private var plants: [Plant]
    @Query(filter: #Predicate<BotanyTerm> { $0.showPlantID == true })
    private var botanyTerms: [BotanyTerm]

    @State private var selectedOrgan: PlantOrgan = .leaf
    @State private var currentQuestionIndex: Int = 0
    @State private var selectedTraits: [String: String] = [:]
    @State private var showResults = false
    @State private var showPaywall = false
    @State private var questionsAnsweredThisSession: Int = 0

    @AppStorage("observeQuestionsToday") private var observeQuestionsToday: Int = 0
    @AppStorage("observeQuestionsDate") private var observeQuestionsDate: String = ""

    private let freeQuestionLimit = 3

    var body: some View {
        VStack(spacing: 0) {
            organSelector
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    progressIndicator
                        .padding(.horizontal, 16)

                    if currentQuestionIndex < currentQuestions.count {
                        traitQuestionCard
                            .padding(.horizontal, 16)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .id("\(selectedOrgan.rawValue)-\(currentQuestionIndex)")
                    } else if !selectedTraits.isEmpty {
                        completedCard
                            .padding(.horizontal, 16)
                    } else {
                        emptyStateCard
                            .padding(.horizontal, 16)
                    }

                    if !selectedTraits.isEmpty {
                        matchProgressCard
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .background(Color.appBackground)
        .animation(.easeInOut(duration: 0.25), value: currentQuestionIndex)
        .animation(.easeInOut(duration: 0.25), value: selectedOrgan)
        .sheet(isPresented: $showResults) {
            resultsModal
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(contextText: "Upgrade to unlock unlimited Observe mode questions.")
        }
        .onChange(of: selectedOrgan) { _, _ in
            resetSession()
        }
    }

    // MARK: - Current Questions

    private var currentQuestions: [TraitQuestion] {
        selectedOrgan.traitQuestions
    }

    // MARK: - Organ Selector

    private var organSelector: some View {
        HStack(spacing: 8) {
            ForEach(PlantOrgan.allCases) { organ in
                Button {
                    selectedOrgan = organ
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: organ.icon)
                            .font(.system(size: 18))
                        Text(organ.rawValue)
                            .font(AppFont.caption())
                    }
                    .foregroundStyle(selectedOrgan == organ ? Color.orangePrimary : Color.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedOrgan == organ ? Color.orangePrimary.opacity(0.12) : Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedOrgan == organ ? Color.orangePrimary.opacity(0.4) : Color.borderSubtle, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(selectedOrgan.rawValue) Traits")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("\(min(currentQuestionIndex, currentQuestions.count)) of \(currentQuestions.count)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.surfaceElevated)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orangePrimary)
                        .frame(
                            width: currentQuestions.isEmpty ? 0 : geometry.size.width * CGFloat(currentQuestionIndex) / CGFloat(currentQuestions.count),
                            height: 4
                        )
                        .animation(.easeInOut, value: currentQuestionIndex)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Trait Question Card

    private var traitQuestionCard: some View {
        let question = currentQuestions[currentQuestionIndex]
        let options = termsForCategory(question.category)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(question.title)
                    .font(AppFont.title(20))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if !storeManager.isFeatureUnlocked(.unlimitedObserve) {
                    let remaining = max(0, freeQuestionLimit - todayQuestionCount)
                    Text("\(remaining) free left")
                        .font(AppFont.caption())
                        .foregroundStyle(remaining > 0 ? Color.textMuted : Color.errorRed)
                }
            }

            Text("Select the trait that best matches your specimen.")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)

            // Options grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(options, id: \.term) { term in
                    traitOptionButton(term: term, questionCategory: question.category)
                }
            }

            // Skip / Not Sure buttons
            HStack(spacing: 12) {
                Button {
                    skipQuestion()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10))
                        Text("Skip")
                    }
                }
                .buttonStyle(GhostButtonStyle())

                Button {
                    skipQuestion()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                        Text("I'm not sure")
                    }
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()

                if currentQuestionIndex > 0 {
                    Button {
                        goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10))
                            Text("Back")
                        }
                    }
                    .buttonStyle(GhostButtonStyle(color: .orangePrimary))
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Trait Option Button

    private func traitOptionButton(term: BotanyTerm, questionCategory: String) -> some View {
        let isSelected = selectedTraits[questionCategory] == term.term

        return Button {
            selectTrait(category: questionCategory, value: term.term)
        } label: {
            VStack(spacing: 6) {
                if let imageURL = term.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            traitPlaceholderImage
                        case .empty:
                            ProgressView()
                                .tint(Color.textMuted)
                                .frame(height: 70)
                        @unknown default:
                            traitPlaceholderImage
                        }
                    }
                } else {
                    traitPlaceholderImage
                }

                Text(term.term)
                    .font(AppFont.caption())
                    .foregroundStyle(isSelected ? Color.orangePrimary : Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(isSelected ? Color.orangePrimary.opacity(0.12) : Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.orangePrimary : Color.borderSubtle, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var traitPlaceholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surface)
                .frame(height: 70)
            Image(systemName: "leaf.fill")
                .font(.title3)
                .foregroundStyle(Color.textMuted.opacity(0.5))
        }
    }

    // MARK: - Completed Card

    private var completedCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.greenSecondary)

            Text("All \(selectedOrgan.rawValue) Traits Answered")
                .font(AppFont.title(20))
                .foregroundStyle(Color.textPrimary)

            Text("Tap the results card below to see your matches.")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                resetSession()
            } label: {
                Text("Start Over")
            }
            .buttonStyle(SecondaryButtonStyle(color: .orangePrimary))
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedOrgan.icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.orangePrimary.opacity(0.6))

            Text("Select a \(selectedOrgan.rawValue) Trait")
                .font(AppFont.title(20))
                .foregroundStyle(Color.textPrimary)

            Text("Answer the trait questions above to narrow down potential species matches.")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Match Progress Card

    private var matchProgressCard: some View {
        let results = computeMatchingPlants()
        let totalSpecies = plants.count
        let matchingCount = results.count

        return Button {
            showResults = true
        } label: {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let topMatch = results.first {
                            HStack(spacing: 6) {
                                Text("Top Match:")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textMuted)
                                Text(topMatch.plant.commonName)
                                    .font(AppFont.sectionHeader())
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                            }

                            Text("\(Int(topMatch.matchPercentage))% match")
                                .font(AppFont.caption())
                                .foregroundStyle(topMatch.matchPercentage >= 50 ? Color.greenSecondary : Color.orangePrimary)
                        } else {
                            Text("No matches yet")
                                .font(AppFont.sectionHeader())
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(matchingCount)")
                            .font(AppFont.title(22))
                            .foregroundStyle(Color.orangePrimary)
                        Text("of \(totalSpecies) species")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)
                    }
                }

                HStack {
                    Text("Tap to see all results")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                }
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orangePrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results Modal

    private var resultsModal: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                let results = computeMatchingPlants()

                if results.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.textMuted)
                        Text("No matching species found")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                        Text("Try adjusting your trait selections.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            HStack {
                                Text("\(results.count) Matching Species")
                                    .font(AppFont.sectionHeader())
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text("Sorted by match %")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textMuted)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                            ForEach(results) { result in
                                resultRow(result)
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showResults = false
                    }
                    .foregroundStyle(Color.orangePrimary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if storeManager.isFeatureUnlocked(.journal) {
                    Button {
                        // Save to journal action would go here
                        showResults = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                            Text("Save to Journal")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                } else {
                    Button {
                        showResults = false
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                            Text("Save to Journal")
                            CategoryPill(text: "LIFETIME+", color: .orangePrimary)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .orangePrimary))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Result Row

    private func resultRow(_ result: PlantMatchResult) -> some View {
        HStack(spacing: 12) {
            // Match circle
            ZStack {
                Circle()
                    .stroke(matchColor(result.matchPercentage).opacity(0.3), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: result.matchPercentage / 100)
                    .stroke(matchColor(result.matchPercentage), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(result.matchPercentage))%")
                    .font(AppFont.caption())
                    .foregroundStyle(matchColor(result.matchPercentage))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(result.plant.scientificName)
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)
                    .italic()

                Text(result.plant.commonName)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)

                Text("\(result.matchedTraits)/\(result.totalTraits) traits matched")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
    }

    // MARK: - Logic

    private func termsForCategory(_ category: String) -> [BotanyTerm] {
        botanyTerms.filter { $0.category == category }
    }

    private func selectTrait(category: String, value: String) {
        // Free user limit check
        if !storeManager.isFeatureUnlocked(.unlimitedObserve) {
            refreshDailyCount()
            if todayQuestionCount >= freeQuestionLimit {
                showPaywall = true
                return
            }
            observeQuestionsToday += 1
        }

        selectedTraits[category] = value
        questionsAnsweredThisSession += 1

        withAnimation {
            if currentQuestionIndex < currentQuestions.count {
                currentQuestionIndex += 1
            }
        }
    }

    private func skipQuestion() {
        withAnimation {
            if currentQuestionIndex < currentQuestions.count {
                currentQuestionIndex += 1
            }
        }
    }

    private func goBack() {
        withAnimation {
            if currentQuestionIndex > 0 {
                currentQuestionIndex -= 1
                let question = currentQuestions[currentQuestionIndex]
                selectedTraits.removeValue(forKey: question.category)
            }
        }
    }

    private func resetSession() {
        currentQuestionIndex = 0
        selectedTraits = [:]
        questionsAnsweredThisSession = 0
    }

    private var todayQuestionCount: Int {
        refreshDailyCount()
        return observeQuestionsToday
    }

    private func refreshDailyCount() {
        let today = formattedToday
        if observeQuestionsDate != today {
            observeQuestionsToday = 0
            observeQuestionsDate = today
        }
    }

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func computeMatchingPlants() -> [PlantMatchResult] {
        guard !selectedTraits.isEmpty else { return [] }

        let questions = currentQuestions
        var results: [PlantMatchResult] = []

        for plant in plants {
            var matchedCount = 0
            var totalCompared = 0

            for question in questions {
                guard let selectedValue = selectedTraits[question.category] else { continue }

                totalCompared += 1
                let plantValue = plant[keyPath: question.keyPath]

                if let plantValue, plantValue.localizedCaseInsensitiveContains(selectedValue) || selectedValue.localizedCaseInsensitiveContains(plantValue) {
                    matchedCount += 1
                }
            }

            guard totalCompared > 0 else { continue }

            let percentage = Double(matchedCount) / Double(totalCompared) * 100.0

            if matchedCount > 0 {
                results.append(PlantMatchResult(
                    plant: plant,
                    matchPercentage: percentage,
                    matchedTraits: matchedCount,
                    totalTraits: totalCompared
                ))
            }
        }

        return results.sorted { $0.matchPercentage > $1.matchPercentage }
    }

    private func matchColor(_ percentage: Double) -> Color {
        if percentage >= 75 {
            return .highConfidence
        } else if percentage >= 50 {
            return .mediumConfidence
        } else {
            return .lowConfidence
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ObserveView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: [Plant.self, BotanyTerm.self], inMemory: true)
    .preferredColorScheme(.dark)
}
