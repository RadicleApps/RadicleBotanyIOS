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
        case .fruit: return "drop.fill"
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
    @StateObject private var viewModel = IdentificationViewModel()

    @State private var showResults = false
    @State private var noteForEditing: JournalNote? = nil
    @State private var fullscreenImage: ImageSource? = nil
    @State private var selectedPlant: Plant? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CaptureImagePreview(
                    image: viewModel.capturedImage,
                    height: 280,
                    showRetake: true,
                    onRetake: { viewModel.reset() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                OrganSelector(
                    selectedOrgan: $viewModel.selectedOrgan,
                    accentColor: .orangePrimary
                )
                .padding(.horizontal, 16)

                CaptureControls(
                    accentColor: .orangePrimary,
                    isDisabled: viewModel.isIdentifying,
                    onCamera: {
                        viewModel.showCamera = true
                    },
                    onLibrary: {
                        viewModel.showPhotoPicker = true
                    }
                )
                .padding(.horizontal, 16)

                if viewModel.isIdentifying {
                    IdentifyingCard(organName: viewModel.selectedOrgan.rawValue)
                        .padding(.horizontal, 16)
                }

                if let result = viewModel.identificationResult, !viewModel.isIdentifying {
                    quickResultsPreview(result)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .background(AppColors.appBackground)
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(image: $viewModel.capturedImage)
                .ignoresSafeArea()
                .onDisappear {
                    if viewModel.capturedImage != nil {
                        viewModel.identifyImage()
                    }
                }
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPickerView(image: $viewModel.capturedImage)
                .onDisappear {
                    if viewModel.capturedImage != nil {
                        viewModel.identifyImage()
                    }
                }
        }
        .sheet(isPresented: $showResults) {
            if let result = viewModel.identificationResult {
                captureResultsModal(result)
            }
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
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.textMuted)

                            Text(best.commonName)
                                .font(AppTypography.headerTitle)
                                .foregroundStyle(AppColors.textPrimary)

                            Text(best.scientificName)
                                .font(AppTypography.fieldLabel)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        Spacer()

                        ConfidenceBadge(score: best.score)
                    }

                    HStack {
                        Text("\(min(result.results.count, 5)) results found")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textMuted)

                        if viewModel.isInLocalDatabase(best.scientificName, plants: plants) {
                            CategoryPill(text: "In Database", color: .greenSecondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("See all")
                                .font(AppTypography.tagText)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.inter(size: 10))
                        }
                        .foregroundStyle(AppColors.primaryAmber)
                    }
                } else {
                    Text("No matches found")
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Capture Results Modal

    private func captureResultsModal(_ result: PlantIdentificationResult) -> some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 2) {
                        ResultsModalHeader(
                            image: viewModel.capturedImage,
                            title: "Identification Results",
                            trailingPill: viewModel.selectedOrgan.rawValue,
                            pillColor: .greenSecondary
                        )

                        let topResults = Array(result.results.prefix(5))

                        ForEach(topResults) { match in
                            let inDB = viewModel.isInLocalDatabase(match.scientificName, plants: plants)
                            IdentificationResultRow(
                                match: match,
                                isInDatabase: inDB,
                                onTap: inDB ? {
                                    if let plant = plants.first(where: {
                                        $0.scientificName.localizedCaseInsensitiveCompare(match.scientificName) == .orderedSame
                                    }) {
                                        selectedPlant = plant
                                    }
                                } : nil,
                                onImageTap: { urlStr in
                                    fullscreenImage = .url(urlStr)
                                }
                            )
                        }

                        if result.results.isEmpty {
                            EmptyResultsPlaceholder()
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
                    .foregroundStyle(AppColors.primaryAmber)
                }
            }
            .safeAreaInset(edge: .bottom) {
                SaveToJournalBar(
                    isUnlocked: storeManager.isFeatureUnlocked(.journal),
                    accentColor: .orangePrimary,
                    onSave: {
                        viewModel.saveToJournal(modelContext: modelContext)
                        showResults = false
                    },
                    onDismiss: { showResults = false },
                    onWriteNote: {
                        createNoteFromCapture(result)
                    }
                )
            }
        }
        .presentationDetents([.large])
    }

    private func createNoteFromCapture(_ result: PlantIdentificationResult) {
        let bestMatch = result.bestMatch
        let title = bestMatch.map { "Observation: \($0.scientificName)" } ?? "Capture Note"
        var content = ""

        if let match = bestMatch {
            content += "\(match.commonName) (\(match.scientificName))\n"
            content += "Confidence: \(Int(match.score * 100))%\n\n"
        }

        let note = JournalNote(
            title: title,
            content: content,
            linkedEntityType: bestMatch != nil ? LinkedEntityType.plant.rawValue : nil,
            linkedEntityID: bestMatch?.scientificName
        )
        modelContext.insert(note)
        showResults = false
        noteForEditing = note
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaptureView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, PlantObservation.self, JournalNote.self], inMemory: true)
    .preferredColorScheme(.dark)
}
