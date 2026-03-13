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

    @Query private var plants: [Plant]
    @Query(filter: #Predicate<BotanyTerm> { $0.showPlantID == true })
    private var botanyTerms: [BotanyTerm]

    @StateObject private var viewModel = IdentificationViewModel()

    // Verification state
    @State private var verificationIndex: Int = 0
    @State private var verifiedTraits: [String: Set<String>] = [:]
    @State private var showFinalResults = false
    @State private var noteForEditing: JournalNote? = nil
    @State private var fullscreenImage: ImageSource? = nil
    @State private var selectedPlant: Plant? = nil

    // Phase: capture first, then verify
    private var isInVerificationPhase: Bool {
        viewModel.identificationResult != nil && !viewModel.isIdentifying
    }

    private var totalVerifiedCount: Int {
        verifiedTraits.values.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            if isInVerificationPhase {
                verificationPhase
            } else {
                capturePhase
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(image: $viewModel.capturedImage)
                .ignoresSafeArea()
                .onDisappear {
                    if viewModel.capturedImage != nil {
                        identifyAndResetVerification()
                    }
                }
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPickerView(image: $viewModel.capturedImage)
                .onDisappear {
                    if viewModel.capturedImage != nil {
                        identifyAndResetVerification()
                    }
                }
        }
        .sheet(isPresented: $showFinalResults) {
            finalResultsModal
        }
        .sheet(item: $noteForEditing) { note in
            NavigationStack {
                NoteEditorView(
                    note: note,
                    isNewNote: true,
                    onDelete: {
                        modelContext.delete(note)
                        noteForEditing = nil
                    }
                )
            }
        }
        .fullScreenCover(item: $fullscreenImage) { source in
            FullscreenImageViewer(source: source)
        }
        .sheet(item: $selectedPlant) { plant in
            NavigationStack {
                PlantDetailView(plant: plant)
            }
        }
        .alert("Identification Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .task {
            await viewModel.setupLocation()
        }
    }

    // MARK: - Capture Phase

    private var capturePhase: some View {
        ScrollView {
            VStack(spacing: 20) {
                CaptureImagePreview(
                    image: viewModel.capturedImage,
                    height: 240,
                    placeholderIcon: "sparkles",
                    placeholderText: "Capture + Verify",
                    placeholderIconColor: .purpleSecondary,
                    showRetake: false
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                OrganSelector(
                    selectedOrgan: $viewModel.selectedOrgan,
                    accentColor: .orangePrimary,
                    showLabel: false
                )
                .padding(.horizontal, 16)

                CaptureControls(
                    accentColor: .orangePrimary,
                    isDisabled: viewModel.isIdentifying,
                    onCamera: { viewModel.showCamera = true },
                    onLibrary: { viewModel.showPhotoPicker = true }
                )
                .padding(.horizontal, 16)

                if viewModel.isIdentifying {
                    IdentifyingCard(
                        organName: viewModel.selectedOrgan.rawValue,
                        subtitle: "After identification, you'll verify traits to refine results."
                    )
                    .padding(.horizontal, 16)
                }

                if viewModel.capturedImage == nil && !viewModel.isIdentifying {
                    instructionsCard
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 100)
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppColors.brandPurple)
                Text("How Both Mode Works")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                instructionStep(number: 1, text: "Take a photo of the plant organ")
                instructionStep(number: 2, text: "Software identifies potential species")
                instructionStep(number: 3, text: "Verify traits to refine accuracy")
                instructionStep(number: 4, text: "Get final confidence-adjusted results")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.brandPurple)
                .frame(width: 22, height: 22)
                .background(AppColors.brandPurple.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Verification Phase

    private var verificationPhase: some View {
        let cards = verificationCards

        return ZStack {
            // Blurred background image
            if let capturedImage = viewModel.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .blur(radius: 20)
                    .overlay(AppColors.appBackground.opacity(0.75))
                    .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                // Top bar with results summary
                verificationHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if !cards.isEmpty && verificationIndex < cards.count {
                    // Swipeable verification cards
                    TabView(selection: $verificationIndex) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            verificationCardView(card, index: index, total: cards.count)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 380)

                    // Skip all button
                    Button {
                        showFinalResults = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "forward.fill")
                                .font(AppTypography.inter(size: 10))
                            Text("Skip to Results")
                        }
                    }
                    .buttonStyle(GhostButtonStyle(color: .purpleSecondary))
                } else {
                    // All cards verified
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
                    Text("Verifying: \(best.titleCasedCommonName)")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    let adjusted = adjustedConfidence(for: best)
                    Text("Confidence: \(Int(adjusted * 100))%")
                        .font(AppTypography.tagText)
                        .foregroundStyle(adjusted >= 0.5 ? AppColors.success : AppColors.primaryAmber)
                }
            }

            Spacer()

            Button {
                resetAll()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(AppTypography.inter(size: 11))
                    Text("New Photo")
                        .font(AppTypography.tagText)
                }
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.cardElevated)
                .clipShape(Capsule())
            }
        }
    }

    private func verificationCardView(_ card: VerificationCard, index: Int, total: Int) -> some View {
        VStack(spacing: 16) {
            // Card header
            HStack {
                Text("Verify: \(card.traitName)")
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("\(index + 1)/\(total)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            Text("Does this match your specimen?")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Options
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(card.options, id: \.term) { term in
                        verificationOptionButton(term: term, card: card)
                    }
                }
                .padding(.bottom, 16)
            }

            // Confirm or Skip
            HStack(spacing: 12) {
                Button {
                    advanceVerification()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                            .font(AppTypography.inter(size: 10))
                        Text("Skip")
                    }
                }
                .buttonStyle(GhostButtonStyle())

                if verifiedTraits[card.category] != nil {
                    Button {
                        advanceVerification()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(AppTypography.inter(size: 12, weight: .bold))
                            Text("Confirm")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .purpleSecondary))
                }
            }
        }
        .padding(20)
        .background(AppColors.cardBackground.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.badge)
                .stroke(AppColors.brandPurple.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func verificationOptionButton(term: BotanyTerm, card: VerificationCard) -> some View {
        let isSelected: Bool = verifiedTraits[card.category]?.contains(term.term) ?? false

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                var current = verifiedTraits[card.category] ?? Set<String>()
                if current.contains(term.term) {
                    current.remove(term.term)
                    if current.isEmpty {
                        _ = verifiedTraits.removeValue(forKey: card.category)
                    } else {
                        verifiedTraits[card.category] = current
                    }
                } else {
                    current.insert(term.term)
                    verifiedTraits[card.category] = current
                }
            }
        } label: {
            verificationButtonLabel(term: term, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func verificationButtonLabel(term: BotanyTerm, isSelected: Bool) -> some View {
        let bgColor: Color = isSelected ? AppColors.brandPurple.opacity(0.12) : AppColors.cardElevated
        let strokeColor: Color = isSelected ? AppColors.brandPurple : AppColors.border
        let strokeWidth: CGFloat = isSelected ? 1.5 : 0.5

        VStack(spacing: 6) {
            verificationTermImage(term: term)

            Text(term.term)
                .font(AppTypography.tagText)
                .foregroundStyle(isSelected ? AppColors.brandPurple : AppColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
    }

    /// Prefer colorImageURL, fall back to imageURL (diagram)
    @ViewBuilder
    private func verificationTermImage(term: BotanyTerm) -> some View {
        let bestURL: URL? = {
            if let c = term.colorImageURL, !c.isEmpty, let u = URL(string: c) { return u }
            if let d = term.imageURL, !d.isEmpty, let u = URL(string: d) { return u }
            return nil
        }()

        if let url = bestURL {
            ThrottledAsyncImage(url: url, contentMode: .fit) {
                verificationPlaceholder
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .clipped()
        } else {
            verificationPlaceholder
        }
    }

    private var verificationPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.button)
                .fill(AppColors.cardBackground)
                .frame(height: 60)
            Image(systemName: "leaf.fill")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted.opacity(0.5))
        }
    }

    private var verificationComplete: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(AppTypography.inter(size: 48))
                .foregroundStyle(AppColors.brandPurple)

            Text("Verification Complete")
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            Text("\(totalVerifiedCount) traits verified")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)

            Button {
                showFinalResults = true
            } label: {
                Text("View Final Results")
            }
            .buttonStyle(PrimaryButtonStyle(color: .purpleSecondary))
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .padding(.horizontal, 16)
    }

    // MARK: - Final Results Modal

    private var finalResultsModal: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 2) {
                        ResultsModalHeader(
                            image: viewModel.capturedImage,
                            title: "Final Results",
                            trailingPill: verifiedTraits.isEmpty ? nil : "\(totalVerifiedCount) verified",
                            pillColor: .orangePrimary,
                            imageHeight: 160
                        )

                        if let result = viewModel.identificationResult {
                            let adjustedResults = computeAdjustedResults(from: result)

                            ForEach(Array(adjustedResults.enumerated()), id: \.element.match.id) { index, adjusted in
                                adjustedResultRow(adjusted, rank: index + 1)
                            }

                            if adjustedResults.isEmpty {
                                EmptyResultsPlaceholder(message: "No results available")
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
                    .foregroundStyle(AppColors.primaryAmber)
                }
            }
            .safeAreaInset(edge: .bottom) {
                SaveToJournalBar(
                    isUnlocked: true,
                    accentColor: .orangePrimary,
                    onSave: {
                        saveToJournal()
                        showFinalResults = false
                    },
                    onDismiss: { showFinalResults = false },
                    onWriteNote: {
                        createNoteFromBothMode()
                    }
                )
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Adjusted Result Row

    private func adjustedResultRow(_ result: AdjustedMatch, rank: Int) -> some View {
        let inDB = viewModel.isInLocalDatabase(result.match.scientificName, plants: plants)
        return Button {
            if inDB, let plant = plants.first(where: {
                $0.scientificName.localizedCaseInsensitiveCompare(result.match.scientificName) == .orderedSame
            }) {
                selectedPlant = plant
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // Rank
                    Text("#\(rank)")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(rank <= 3 ? AppColors.primaryAmber : AppColors.textMuted)
                        .frame(width: 30)

                    // Confidence indicator
                    VStack(spacing: 2) {
                        Text("\(Int(result.adjustedScore * 100))%")
                            .font(AppTypography.sectionHeader)
                            .foregroundStyle(result.adjustedScore >= 0.5 ? AppColors.highConfidence : AppColors.mediumConfidence)

                        if result.adjustedScore != result.match.score {
                            let delta = result.adjustedScore - result.match.score
                            HStack(spacing: 1) {
                                Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                                    .font(AppTypography.inter(size: 8))
                                Text("\(abs(Int(delta * 100)))%")
                                    .font(AppTypography.inter(size: 9))
                            }
                            .foregroundStyle(delta >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                    .frame(width: 50)

                    // Species info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.match.scientificName)
                            .font(AppTypography.sectionHeader)
                            .foregroundStyle(AppColors.textPrimary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)

                        Text(result.match.titleCasedCommonName)
                            .font(AppTypography.bodyText)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if result.verifiedTraitCount > 0 {
                            Text("\(result.verifiedTraitCount) trait\(result.verifiedTraitCount == 1 ? "" : "s") verified")
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.primaryAmber)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if inDB {
                        VStack(alignment: .trailing, spacing: 4) {
                            CategoryPill(text: "In DB", color: .orangePrimary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.inter(size: 10))
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }

                // Reference images
                if let images = result.match.images, !images.isEmpty {
                    ReferenceImageStrip(images: images, onImageTap: { urlStr in
                        fullscreenImage = .url(urlStr)
                    })
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                return PlantOrgan.stem.traitQuestions
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

    private func identifyAndResetVerification() {
        verifiedTraits = [:]
        verificationIndex = 0
        viewModel.identifyImage()
    }

    private func adjustedConfidence(for match: PlantMatch) -> Double {
        guard !verifiedTraits.isEmpty else { return match.score }

        let localPlant = plants.first { $0.scientificName.lowercased() == match.scientificName.lowercased() }
        guard let localPlant else { return match.score }

        var bonus: Double = 0

        for card in verificationCards {
            guard let verifiedValues = verifiedTraits[card.category], !verifiedValues.isEmpty else { continue }

            let plantValue = localPlant[keyPath: card.keyPath]
            if let plantValue {
                let matched = verifiedValues.contains { verified in
                    plantValue.localizedCaseInsensitiveContains(verified) || verified.localizedCaseInsensitiveContains(plantValue)
                }
                bonus += matched ? 0.05 : -0.03
            } else {
                bonus -= 0.03
            }
        }

        return min(1.0, max(0, match.score + bonus))
    }

    struct AdjustedMatch {
        let match: PlantMatch
        let adjustedScore: Double
        let verifiedTraitCount: Int
    }

    private func computeAdjustedResults(from result: PlantIdentificationResult) -> [AdjustedMatch] {
        let topMatches = Array(result.results.prefix(5))

        return topMatches.map { match in
            let localPlant = plants.first { $0.scientificName.lowercased() == match.scientificName.lowercased() }

            var bonus: Double = 0
            var verifiedCount = 0

            if let localPlant {
                for card in verificationCards {
                    guard let verifiedValues = verifiedTraits[card.category], !verifiedValues.isEmpty else { continue }

                    let plantValue = localPlant[keyPath: card.keyPath]
                    if let plantValue {
                        let matched = verifiedValues.contains { verified in
                            plantValue.localizedCaseInsensitiveContains(verified) || verified.localizedCaseInsensitiveContains(plantValue)
                        }
                        if matched {
                            bonus += 0.05
                            verifiedCount += 1
                        } else {
                            bonus -= 0.03
                        }
                    } else {
                        bonus -= 0.03
                    }
                }
            }

            let adjusted = min(1.0, max(0, match.score + bonus))
            return AdjustedMatch(match: match, adjustedScore: adjusted, verifiedTraitCount: verifiedCount)
        }
        .sorted { $0.adjustedScore > $1.adjustedScore }
    }

    private func resetAll() {
        viewModel.reset()
        verifiedTraits = [:]
        verificationIndex = 0
    }

    private func saveToJournal() {
        guard let result = viewModel.identificationResult,
              let bestMatch = result.bestMatch else { return }

        let adjustedResults = computeAdjustedResults(from: result)
        let topAdjusted = adjustedResults.first
        let flattenedTraits = verifiedTraits.values.flatMap { $0 }.sorted()

        viewModel.saveToJournal(
            modelContext: modelContext,
            notes: "Identified via Both mode. Original: \(Int(bestMatch.score * 100))%, Adjusted: \(Int((topAdjusted?.adjustedScore ?? bestMatch.score) * 100))%. Verified \(totalVerifiedCount) traits.",
            verifiedTraits: Array(flattenedTraits)
        )
    }

    private func createNoteFromBothMode() {
        guard let result = viewModel.identificationResult else { return }

        let bestMatch = result.bestMatch
        let adjustedResults = computeAdjustedResults(from: result)
        let topAdjusted = adjustedResults.first
        let title = bestMatch.map { "Observation: \($0.scientificName)" } ?? "Both Mode Note"
        var content = ""

        if let match = bestMatch {
            content += "\(match.titleCasedCommonName) (\(match.scientificName))\n"
            let originalScore = Int(match.score * 100)
            let adjustedScore = Int((topAdjusted?.adjustedScore ?? match.score) * 100)
            content += "Confidence: \(originalScore)% \u{2192} Adjusted: \(adjustedScore)%\n\n"
        }

        let flatTraits = verifiedTraits
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.sorted().joined(separator: ", "))" }
            .joined(separator: "\n")

        if !flatTraits.isEmpty {
            content += "Verified traits:\n\(flatTraits)\n\n"
        }

        let note = JournalNote(
            title: title,
            content: content,
            linkedEntityType: bestMatch != nil ? LinkedEntityType.plant.rawValue : nil,
            linkedEntityID: bestMatch?.scientificName
        )
        modelContext.insert(note)
        showFinalResults = false
        noteForEditing = note
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BothModeView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, BotanyTerm.self, PlantObservation.self, JournalNote.self], inMemory: true)
    .preferredColorScheme(.dark)
}
