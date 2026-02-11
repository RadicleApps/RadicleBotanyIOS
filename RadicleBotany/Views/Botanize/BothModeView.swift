import SwiftUI
import SwiftData

// MARK: - Verification Card

struct VerificationCard: Identifiable {
    let id = UUID()
    let traitName: String
    let category: String
    let keyPath: KeyPath<Plant, String?>
    let options: [BotanyTerm]
}

// MARK: - BothModeView

struct BothModeView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = IdentificationViewModel()
    @State private var botanyTerms: [BotanyTerm] = []

    // Verification state
    @State private var verificationIndex: Int = 0
    @State private var verifiedTraits: [String: String] = [:]
    @State private var showFinalResults = false

    private var isInVerificationPhase: Bool {
        viewModel.identificationResult != nil && !viewModel.isIdentifying
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isInVerificationPhase {
                verificationPhase
            } else {
                capturePhase
            }
        }
        .navigationTitle("Both Mode")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(image: $viewModel.capturedImage)
                .ignoresSafeArea()
                .onDisappear {
                    if viewModel.capturedImage != nil {
                        verifiedTraits = [:]
                        verificationIndex = 0
                        viewModel.identifyImage()
                    }
                }
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPickerView(image: $viewModel.capturedImage)
                .onDisappear {
                    if viewModel.capturedImage != nil {
                        verifiedTraits = [:]
                        verificationIndex = 0
                        viewModel.identifyImage()
                    }
                }
        }
        .sheet(isPresented: $showFinalResults) {
            finalResultsModal
        }
        .onAppear { loadData() }
        .alert("Identification Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Capture Phase

    private var capturePhase: some View {
        ScrollView {
            VStack(spacing: 20) {
                CaptureAreaView(
                    capturedImage: viewModel.capturedImage,
                    height: 240,
                    placeholderIcon: "sparkles",
                    placeholderTitle: "Capture + Verify",
                    placeholderSubtitle: "Take a photo, then verify traits for accurate results",
                    accentColor: .purpleSecondary
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                OrganSelectorView(
                    selectedOrgan: $viewModel.selectedOrgan,
                    accentColor: .purpleSecondary
                )
                .padding(.horizontal, 16)

                CaptureControlsView(
                    accentColor: .purpleSecondary,
                    isDisabled: viewModel.isIdentifying,
                    onCamera: { viewModel.showCamera = true },
                    onLibrary: { viewModel.showPhotoPicker = true }
                )
                .padding(.horizontal, 16)

                if viewModel.isIdentifying {
                    IdentifyingCardView(
                        organName: viewModel.selectedOrgan.rawValue,
                        subtitle: "After identification, you'll verify traits to refine results."
                    )
                    .padding(.horizontal, 16)
                }

                if viewModel.capturedImage == nil && !viewModel.isIdentifying {
                    instructionsCard
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.purpleSecondary)
                Text("How Both Mode Works")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                instructionStep(number: 1, text: "Take a photo of the plant organ")
                instructionStep(number: 2, text: "AI identifies potential species")
                instructionStep(number: 3, text: "Verify traits to refine accuracy")
                instructionStep(number: 4, text: "Get final confidence-adjusted results")
            }
        }
        .cardStyle()
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(AppFont.caption())
                .foregroundStyle(Color.purpleSecondary)
                .frame(width: 22, height: 22)
                .background(Color.purpleSecondary.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Verification Phase

    private var verificationPhase: some View {
        let cards = verificationCards

        return ZStack {
            if let capturedImage = viewModel.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .overlay(Color.appBackground.opacity(0.75))
                    .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                verificationHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if !cards.isEmpty && verificationIndex < cards.count {
                    TabView(selection: $verificationIndex) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            verificationCardView(card, index: index, total: cards.count)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 380)

                    Button {
                        showFinalResults = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 10))
                            Text("Skip to Results")
                        }
                    }
                    .buttonStyle(GhostButtonStyle(color: .purpleSecondary))
                } else {
                    verificationComplete
                }

                Spacer()
            }
        }
    }

    private var verificationHeader: some View {
        HStack {
            if let best = viewModel.identificationResult?.bestMatch {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verifying: \(viewModel.commonNamesDisplay(for: best))")
                        .font(AppFont.sectionHeader())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    let adjusted = adjustedConfidence(for: best)
                    Text("Confidence: \(Int(adjusted * 100))%")
                        .font(AppFont.caption())
                        .foregroundStyle(adjusted >= 0.5 ? Color.greenSecondary : Color.orangePrimary)
                }
            }

            Spacer()

            Button {
                resetAll()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                    Text("New Photo")
                        .font(AppFont.caption())
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.surfaceElevated)
                .clipShape(Capsule())
            }
        }
    }

    private func verificationCardView(_ card: VerificationCard, index: Int, total: Int) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Verify: \(card.traitName)")
                    .font(AppFont.title(18))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Text("\(index + 1)/\(total)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

            Text("Does this match your specimen?")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(card.options, id: \.term) { term in
                        verificationOptionButton(term: term, card: card)
                    }
                }
            }

            Button {
                advanceVerification()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                    Text("Skip")
                }
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(20)
        .background(Color.surface.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purpleSecondary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func verificationOptionButton(term: BotanyTerm, card: VerificationCard) -> some View {
        let isSelected = verifiedTraits[card.category] == term.term

        return Button {
            verifiedTraits[card.category] = term.term
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                advanceVerification()
            }
        } label: {
            VStack(spacing: 6) {
                if let imageURL = term.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            verificationPlaceholder
                        case .empty:
                            ProgressView()
                                .tint(Color.textMuted)
                                .frame(height: 60)
                        @unknown default:
                            verificationPlaceholder
                        }
                    }
                } else {
                    verificationPlaceholder
                }

                Text(term.term)
                    .font(AppFont.caption())
                    .foregroundStyle(isSelected ? Color.purpleSecondary : Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(isSelected ? Color.purpleSecondary.opacity(0.12) : Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purpleSecondary : Color.borderSubtle, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var verificationPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surface)
                .frame(height: 60)
            Image(systemName: "leaf.fill")
                .font(.caption)
                .foregroundStyle(Color.textMuted.opacity(0.5))
        }
    }

    private var verificationComplete: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.purpleSecondary)

            Text("Verification Complete")
                .font(AppFont.title(22))
                .foregroundStyle(Color.textPrimary)

            Text("\(verifiedTraits.count) traits verified")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)

            Button {
                showFinalResults = true
            } label: {
                Text("View Final Results")
            }
            .buttonStyle(PrimaryButtonStyle(color: .purpleSecondary))
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
        .padding(.horizontal, 16)
    }

    // MARK: - Final Results Modal

    private var finalResultsModal: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 2) {
                        if let image = viewModel.capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                        }

                        HStack {
                            Text("Final Results")
                                .font(AppFont.sectionHeader())
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            if !verifiedTraits.isEmpty {
                                CategoryPill(text: "\(verifiedTraits.count) verified", color: .purpleSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        if let result = viewModel.identificationResult {
                            let adjustedResults = computeAdjustedResults(from: result)

                            ForEach(Array(adjustedResults.enumerated()), id: \.element.match.id) { index, adjusted in
                                adjustedResultRow(adjusted, rank: index + 1)
                            }

                            if adjustedResults.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 30))
                                        .foregroundStyle(Color.textMuted)
                                    Text("No results available")
                                        .font(AppFont.body())
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Both Mode Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showFinalResults = false
                    }
                    .foregroundStyle(Color.purpleSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                SaveToJournalButton(
                    isUnlocked: storeManager.isFeatureUnlocked(.journal),
                    accentColor: .purpleSecondary,
                    onSave: {
                        let adjustedResults = viewModel.identificationResult.map { computeAdjustedResults(from: $0) }
                        viewModel.saveBothModeToJournal(
                            context: modelContext,
                            adjustedMatch: adjustedResults?.first,
                            verifiedTraits: verifiedTraits
                        )
                        showFinalResults = false
                    },
                    onDismiss: {
                        showFinalResults = false
                    }
                )
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Adjusted Result Row

    private func adjustedResultRow(_ result: BothModeAdjustedMatch, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(AppFont.sectionHeader())
                .foregroundStyle(rank <= 3 ? Color.purpleSecondary : Color.textMuted)
                .frame(width: 30)

            VStack(spacing: 2) {
                Text("\(Int(result.adjustedScore * 100))%")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(result.adjustedScore >= 0.5 ? Color.highConfidence : Color.mediumConfidence)

                if result.adjustedScore != result.match.score {
                    let delta = result.adjustedScore - result.match.score
                    HStack(spacing: 1) {
                        Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                        Text("\(abs(Int(delta * 100)))%")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(delta >= 0 ? Color.greenSecondary : Color.errorRed)
                }
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.match.scientificName)
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)
                    .italic()

                Text(viewModel.commonNamesDisplay(for: result.match))
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)

                if result.verifiedTraitCount > 0 {
                    Text("\(result.verifiedTraitCount) trait\(result.verifiedTraitCount == 1 ? "" : "s") verified")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.purpleSecondary)
                }
            }

            Spacer()

            if viewModel.isInLocalDatabase(result.match.scientificName) {
                CategoryPill(text: "In DB", color: .greenSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
    }

    // MARK: - Logic

    private var verificationCards: [VerificationCard] {
        let organQuestions: [TraitQuestion] = {
            switch viewModel.selectedOrgan {
            case .flower:
                return PlantOrgan.flower.traitQuestions
            case .leaf:
                return PlantOrgan.leaf.traitQuestions
            case .fruit:
                return PlantOrgan.fruit.traitQuestions
            case .bark:
                return PlantOrgan.bark.traitQuestions
            }
        }()

        return organQuestions.compactMap { question in
            let options = botanyTerms.filter { $0.category == question.category }
            guard !options.isEmpty else { return nil }
            return VerificationCard(
                traitName: question.title,
                category: question.category,
                keyPath: question.keyPath,
                options: options
            )
        }
    }

    private func advanceVerification() {
        let cards = verificationCards
        withAnimation {
            if verificationIndex < cards.count - 1 {
                verificationIndex += 1
            } else {
                showFinalResults = true
            }
        }
    }

    private func adjustedConfidence(for match: PlantMatch) -> Double {
        guard !verifiedTraits.isEmpty else { return match.score }

        let localPlant = viewModel.localPlant(for: match.scientificName)
        guard let localPlant else { return match.score }

        var bonus: Double = 0

        for card in verificationCards {
            guard let verifiedValue = verifiedTraits[card.category] else { continue }

            let plantValue = localPlant[keyPath: card.keyPath]
            if let plantValue, plantValue.localizedCaseInsensitiveContains(verifiedValue) || verifiedValue.localizedCaseInsensitiveContains(plantValue) {
                bonus += 0.05
            } else {
                bonus -= 0.03
            }
        }

        return min(1.0, max(0, match.score + bonus))
    }

    private func computeAdjustedResults(from result: PlantIdentificationResult) -> [BothModeAdjustedMatch] {
        let topMatches = Array(result.results.prefix(5))

        return topMatches.map { match in
            let localPlant = viewModel.localPlant(for: match.scientificName)

            var bonus: Double = 0
            var verifiedCount = 0

            if let localPlant {
                for card in verificationCards {
                    guard let verifiedValue = verifiedTraits[card.category] else { continue }

                    let plantValue = localPlant[keyPath: card.keyPath]
                    if let plantValue, plantValue.localizedCaseInsensitiveContains(verifiedValue) || verifiedValue.localizedCaseInsensitiveContains(plantValue) {
                        bonus += 0.05
                        verifiedCount += 1
                    } else {
                        bonus -= 0.03
                    }
                }
            }

            let adjusted = min(1.0, max(0, match.score + bonus))
            return BothModeAdjustedMatch(match: match, adjustedScore: adjusted, verifiedTraitCount: verifiedCount)
        }
        .sorted { $0.adjustedScore > $1.adjustedScore }
    }

    private func resetAll() {
        viewModel.reset()
        verifiedTraits = [:]
        verificationIndex = 0
    }

    private func loadData() {
        viewModel.loadPlants(from: modelContext)
        let allTerms = (try? modelContext.fetch(FetchDescriptor<BotanyTerm>())) ?? []
        botanyTerms = allTerms.filter { $0.showPlantID }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BothModeView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: [Plant.self, BotanyTerm.self, PlantObservation.self], inMemory: true)
    .preferredColorScheme(.dark)
}
