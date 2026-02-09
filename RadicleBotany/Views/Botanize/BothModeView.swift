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

    // Capture state
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedOrgan: CaptureOrgan = .flower
    @State private var isIdentifying = false
    @State private var identificationResult: PlantIdentificationResult?
    @State private var errorMessage: String?
    @State private var showError = false

    // Verification state
    @State private var verificationIndex: Int = 0
    @State private var verifiedTraits: [String: String] = [:]
    @State private var showFinalResults = false

    // Phase: capture first, then verify
    private var isInVerificationPhase: Bool {
        identificationResult != nil && !isIdentifying
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
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
                .ignoresSafeArea()
                .onDisappear {
                    if capturedImage != nil {
                        identifyImage()
                    }
                }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(image: $capturedImage)
                .onDisappear {
                    if capturedImage != nil {
                        identifyImage()
                    }
                }
        }
        .sheet(isPresented: $showFinalResults) {
            finalResultsModal
        }
        .alert("Identification Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Capture Phase

    private var capturePhase: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Capture area
                captureArea
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Organ selector
                bothOrganSelector
                    .padding(.horizontal, 16)

                // Capture controls
                bothCaptureControls
                    .padding(.horizontal, 16)

                // Loading
                if isIdentifying {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.orangePrimary)
                            .scaleEffect(1.1)

                        Text("Identifying...")
                            .font(AppFont.sectionHeader())
                            .foregroundStyle(Color.textPrimary)

                        Text("After identification, you'll verify traits to refine results.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle()
                    .padding(.horizontal, 16)
                }

                // Instructions
                if capturedImage == nil && !isIdentifying {
                    instructionsCard
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
        }
    }

    private var captureArea: some View {
        ZStack {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surface)
                    .frame(height: 240)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.purpleSecondary.opacity(0.5))

                            Text("Capture + Verify")
                                .font(AppFont.sectionHeader())
                                .foregroundStyle(Color.textSecondary)

                            Text("Take a photo, then verify traits for accurate results")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.borderSubtle, lineWidth: 0.5)
                    )
            }
        }
    }

    private var bothOrganSelector: some View {
        HStack(spacing: 8) {
            ForEach(CaptureOrgan.allCases) { organ in
                Button {
                    selectedOrgan = organ
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: organ.icon)
                            .font(.system(size: 13))
                        Text(organ.rawValue)
                            .font(AppFont.caption())
                    }
                    .foregroundStyle(selectedOrgan == organ ? Color.purpleSecondary : Color.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedOrgan == organ ? Color.purpleSecondary.opacity(0.12) : Color.surface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedOrgan == organ ? Color.purpleSecondary.opacity(0.4) : Color.borderSubtle, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bothCaptureControls: some View {
        HStack(spacing: 32) {
            Button {
                showPhotoPicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(Color.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("Library")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            }
            .buttonStyle(.plain)

            Button {
                showCamera = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.purpleSecondary, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(Color.textPrimary)
                        .frame(width: 58, height: 58)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.appBackground)
                }
            }
            .buttonStyle(.plain)
            .disabled(isIdentifying)

            // Placeholder for layout balance
            VStack(spacing: 4) {
                Color.clear
                    .frame(width: 48, height: 48)
                Text("")
                    .font(AppFont.caption())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
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
            // Blurred background image
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .overlay(Color.appBackground.opacity(0.75))
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
                                .font(.system(size: 10))
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
            if let best = identificationResult?.bestMatch {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verifying: \(best.commonName)")
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
            // Card header
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
            }

            // Skip this trait
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
            // Auto-advance after short delay
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
                        // Header with captured image
                        if let image = capturedImage {
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

                        // Adjusted results
                        if let result = identificationResult {
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
                if storeManager.isFeatureUnlocked(.journal) {
                    Button {
                        saveToJournal()
                        showFinalResults = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                            Text("Save to Journal")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .purpleSecondary))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                } else {
                    Button {
                        showFinalResults = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                            Text("Save to Journal")
                            CategoryPill(text: "LIFETIME+", color: .orangePrimary)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .purpleSecondary))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.appBackground)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Adjusted Result Row

    private func adjustedResultRow(_ result: AdjustedMatch, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(AppFont.sectionHeader())
                .foregroundStyle(rank <= 3 ? Color.purpleSecondary : Color.textMuted)
                .frame(width: 30)

            // Confidence indicator
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

            // Species info
            VStack(alignment: .leading, spacing: 3) {
                Text(result.match.scientificName)
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)
                    .italic()

                Text(result.match.commonName)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)

                if result.verifiedTraitCount > 0 {
                    Text("\(result.verifiedTraitCount) trait\(result.verifiedTraitCount == 1 ? "" : "s") verified")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.purpleSecondary)
                }
            }

            Spacer()

            if isInLocalDatabase(result.match.scientificName) {
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
            switch selectedOrgan {
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

    private func identifyImage() {
        guard let image = capturedImage else { return }
        identificationResult = nil
        isIdentifying = true
        verifiedTraits = [:]
        verificationIndex = 0

        Task {
            do {
                let result = try await PlantNetService.shared.identifyPlant(image: image)
                await MainActor.run {
                    identificationResult = result
                    isIdentifying = false
                }
            } catch {
                await MainActor.run {
                    isIdentifying = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func adjustedConfidence(for match: PlantMatch) -> Double {
        guard !verifiedTraits.isEmpty else { return match.score }

        let localPlant = plants.first { $0.scientificName.lowercased() == match.scientificName.lowercased() }
        guard let localPlant else { return match.score }

        var bonus: Double = 0
        var checked: Int = 0

        for card in verificationCards {
            guard let verifiedValue = verifiedTraits[card.category] else { continue }
            checked += 1

            let plantValue = localPlant[keyPath: card.keyPath]
            if let plantValue, plantValue.localizedCaseInsensitiveContains(verifiedValue) || verifiedValue.localizedCaseInsensitiveContains(plantValue) {
                bonus += 0.05
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
            return AdjustedMatch(match: match, adjustedScore: adjusted, verifiedTraitCount: verifiedCount)
        }
        .sorted { $0.adjustedScore > $1.adjustedScore }
    }

    private func isInLocalDatabase(_ scientificName: String) -> Bool {
        plants.contains { $0.scientificName.lowercased() == scientificName.lowercased() }
    }

    private func resetAll() {
        capturedImage = nil
        identificationResult = nil
        verifiedTraits = [:]
        verificationIndex = 0
        isIdentifying = false
    }

    private func saveToJournal() {
        guard let result = identificationResult,
              let bestMatch = result.bestMatch else { return }

        let adjustedResults = computeAdjustedResults(from: result)
        let topAdjusted = adjustedResults.first

        let observation = Observation(
            plantScientificName: topAdjusted?.match.scientificName ?? bestMatch.scientificName,
            photoData: capturedImage?.jpegData(compressionQuality: 0.7),
            date: .now,
            notes: "Identified via Both mode. Original: \(Int(bestMatch.score * 100))%, Adjusted: \(Int((topAdjusted?.adjustedScore ?? bestMatch.score) * 100))%. Verified \(verifiedTraits.count) traits.",
            verifiedTraits: Array(verifiedTraits.values)
        )
        modelContext.insert(observation)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BothModeView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: [Plant.self, BotanyTerm.self, Observation.self], inMemory: true)
    .preferredColorScheme(.dark)
}
