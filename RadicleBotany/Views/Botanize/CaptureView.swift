import SwiftUI
import SwiftData

// MARK: - Capture Organ

enum CaptureOrgan: String, CaseIterable, Identifiable {
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

    var plantNetOrgan: String {
        switch self {
        case .flower: return "flower"
        case .leaf: return "leaf"
        case .fruit: return "fruit"
        case .bark: return "bark"
        }
    }
}

// MARK: - CaptureView

struct CaptureView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query private var plants: [Plant]

    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedOrgan: CaptureOrgan = .flower
    @State private var isIdentifying = false
    @State private var identificationResult: PlantIdentificationResult?
    @State private var showResults = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                captureArea
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                organSelector
                    .padding(.horizontal, 16)

                captureControls
                    .padding(.horizontal, 16)

                if isIdentifying {
                    identifyingCard
                        .padding(.horizontal, 16)
                }

                if let result = identificationResult, !isIdentifying {
                    quickResultsPreview(result)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground)
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
        .sheet(isPresented: $showResults) {
            if let result = identificationResult {
                captureResultsModal(result)
            }
        }
        .alert("Identification Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Capture Area

    private var captureArea: some View {
        ZStack {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Overlay for re-capture
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            self.capturedImage = nil
                            self.identificationResult = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12))
                                Text("Retake")
                                    .font(AppFont.caption())
                            }
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .padding(12)
                    }
                }
            } else {
                // Dark placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surface)
                    .frame(height: 280)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.textMuted.opacity(0.4))

                            Text("Take or select a photo")
                                .font(AppFont.body())
                                .foregroundStyle(Color.textMuted)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.borderSubtle, lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Organ Selector

    private var organSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ORGAN TYPE")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)

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
                        .foregroundStyle(selectedOrgan == organ ? Color.orangePrimary : Color.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedOrgan == organ ? Color.orangePrimary.opacity(0.12) : Color.surface)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedOrgan == organ ? Color.orangePrimary.opacity(0.4) : Color.borderSubtle, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Capture Controls

    private var captureControls: some View {
        HStack(spacing: 32) {
            // Photo library button
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

            // Capture button
            Button {
                showCamera = true
            } label: {
                ZStack {
                    // Outer orange ring
                    Circle()
                        .stroke(Color.orangePrimary, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    // Inner white circle
                    Circle()
                        .fill(Color.textPrimary)
                        .frame(width: 58, height: 58)

                    // Camera icon
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.appBackground)
                }
            }
            .buttonStyle(.plain)
            .disabled(isIdentifying)

            // Spacer placeholder to balance layout
            VStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Auto")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }
            .opacity(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Identifying Card

    private var identifyingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.orangePrimary)
                .scaleEffect(1.1)

            Text("Identifying...")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)

            Text("Analyzing your \(selectedOrgan.rawValue.lowercased()) photo")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Quick Results Preview

    private func quickResultsPreview(_ result: PlantIdentificationResult) -> some View {
        Button {
            showResults = true
        } label: {
            VStack(spacing: 12) {
                if let best = result.bestMatch {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Top Result")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)

                            Text(best.commonName)
                                .font(AppFont.title(18))
                                .foregroundStyle(Color.textPrimary)

                            Text(best.scientificName)
                                .font(AppFont.italic())
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        confidenceBadge(score: best.score)
                    }

                    HStack {
                        Text("\(min(result.results.count, 5)) results found")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)

                        if isInLocalDatabase(best.scientificName) {
                            CategoryPill(text: "In Database", color: .greenSecondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("See all")
                                .font(AppFont.caption())
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.orangePrimary)
                    }
                } else {
                    Text("No matches found")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
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

    // MARK: - Capture Results Modal

    private func captureResultsModal(_ result: PlantIdentificationResult) -> some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 2) {
                        // Header
                        if let image = capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                        }

                        HStack {
                            Text("Identification Results")
                                .font(AppFont.sectionHeader())
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            CategoryPill(text: selectedOrgan.rawValue, color: .greenSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        // Top 5 matches
                        let topResults = Array(result.results.prefix(5))

                        ForEach(topResults) { match in
                            captureResultRow(match)
                        }

                        if result.results.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 30))
                                    .foregroundStyle(Color.textMuted)
                                Text("No species identified")
                                    .font(AppFont.body())
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.bottom, 100)
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
                        saveToJournal()
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

    // MARK: - Capture Result Row

    private func captureResultRow(_ match: PlantMatch) -> some View {
        HStack(spacing: 12) {
            confidenceBadge(score: match.score)

            VStack(alignment: .leading, spacing: 3) {
                Text(match.scientificName)
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)
                    .italic()

                Text(match.commonName)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)

                if let family = match.species.family?.scientificNameWithoutAuthor {
                    Text(family)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            }

            Spacer()

            if isInLocalDatabase(match.scientificName) {
                VStack(spacing: 4) {
                    CategoryPill(text: "In Database", color: .greenSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
            } else {
                Text("API")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.surfaceElevated)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface)
    }

    // MARK: - Confidence Badge

    private func confidenceBadge(score: Double) -> some View {
        let percentage = Int(score * 100)
        let color: Color = score >= 0.5 ? .highConfidence : .mediumConfidence

        return VStack(spacing: 2) {
            Text("\(percentage)%")
                .font(AppFont.sectionHeader())
                .foregroundStyle(color)

            Text("match")
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(width: 48, height: 48)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Logic

    private func identifyImage() {
        guard let image = capturedImage else { return }
        identificationResult = nil
        isIdentifying = true

        Task {
            do {
                let result = try await PlantNetService.shared.identifyPlant(image: image)
                await MainActor.run {
                    identificationResult = result
                    isIdentifying = false
                    if !result.results.isEmpty {
                        showResults = true
                    }
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

    private func isInLocalDatabase(_ scientificName: String) -> Bool {
        plants.contains { $0.scientificName.lowercased() == scientificName.lowercased() }
    }

    private func saveToJournal() {
        guard let bestMatch = identificationResult?.bestMatch else { return }

        let observation = Observation(
            plantScientificName: bestMatch.scientificName,
            photoData: capturedImage?.jpegData(compressionQuality: 0.7),
            date: .now,
            notes: "Identified via Capture mode with \(Int(bestMatch.score * 100))% confidence."
        )
        modelContext.insert(observation)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaptureView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: [Plant.self, Observation.self], inMemory: true)
    .preferredColorScheme(.dark)
}
