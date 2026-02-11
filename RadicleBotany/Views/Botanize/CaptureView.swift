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

    @StateObject private var viewModel = IdentificationViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CaptureAreaView(
                    capturedImage: viewModel.capturedImage,
                    height: 280,
                    placeholderIcon: "camera.fill",
                    placeholderTitle: "Take a Photo",
                    placeholderSubtitle: "Take or select a photo to identify",
                    accentColor: .textMuted,
                    onRetake: { viewModel.retake() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                OrganSelectorView(
                    selectedOrgan: $viewModel.selectedOrgan,
                    accentColor: .orangePrimary
                )
                .padding(.horizontal, 16)

                CaptureControlsView(
                    accentColor: .orangePrimary,
                    isDisabled: viewModel.isIdentifying,
                    onCamera: { viewModel.showCamera = true },
                    onLibrary: { viewModel.showPhotoPicker = true }
                )
                .padding(.horizontal, 16)

                if viewModel.isIdentifying {
                    IdentifyingCardView(organName: viewModel.selectedOrgan.rawValue)
                        .padding(.horizontal, 16)
                }

                if let result = viewModel.identificationResult, !viewModel.isIdentifying {
                    QuickResultsPreview(
                        result: result,
                        isInDatabase: { viewModel.isInLocalDatabase($0) },
                        commonNamesDisplay: result.bestMatch.map { viewModel.commonNamesDisplay(for: $0) },
                        onTap: { viewModel.showResults = true }
                    )
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground)
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
        .sheet(isPresented: $viewModel.showResults) {
            if let result = viewModel.identificationResult {
                captureResultsModal(result)
            }
        }
        .alert("Identification Error", isPresented: $viewModel.showError) {
            Button("Retry") { viewModel.identifyImage() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .onAppear { viewModel.loadPlants(from: modelContext) }
    }

    // MARK: - Capture Results Modal

    private func captureResultsModal(_ result: PlantIdentificationResult) -> some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 2) {
                        if let image = viewModel.capturedImage {
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
                            CategoryPill(text: viewModel.selectedOrgan.rawValue, color: .greenSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        let topResults = Array(result.results.prefix(5))

                        ForEach(topResults) { match in
                            IdentificationResultRow(
                                match: match,
                                isInDatabase: viewModel.isInLocalDatabase(match.scientificName),
                                commonNamesDisplay: viewModel.commonNamesDisplay(for: match)
                            )
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
                        viewModel.showResults = false
                    }
                    .foregroundStyle(Color.orangePrimary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                SaveToJournalButton(
                    isUnlocked: storeManager.isFeatureUnlocked(.journal),
                    accentColor: .orangePrimary,
                    onSave: {
                        viewModel.saveToJournal(context: modelContext)
                        viewModel.showResults = false
                    },
                    onDismiss: {
                        viewModel.showResults = false
                    }
                )
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaptureView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: [Plant.self, PlantObservation.self], inMemory: true)
    .preferredColorScheme(.dark)
}
