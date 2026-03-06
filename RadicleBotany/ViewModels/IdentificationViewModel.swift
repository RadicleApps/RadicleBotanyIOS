import SwiftUI
import SwiftData

// MARK: - Identification ViewModel

/// Shared ViewModel for plant identification logic used by both CaptureView and BothModeView.
/// Handles the PlantNet API call, local database lookup, journal saving, and location/project fetching.
@MainActor
final class IdentificationViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var selectedOrgan: CaptureOrgan = .flower
    @Published var isIdentifying = false
    @Published var identificationResult: PlantIdentificationResult?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showCamera = false
    @Published var showPhotoPicker = false

    /// Identify the captured image using PlantNet API with region-specific project.
    func identifyImage() {
        guard let image = capturedImage else { return }
        identificationResult = nil
        isIdentifying = true

        Task {
            do {
                let project = LocationManager.shared.regionalProject ?? "all"
                let result = try await PlantNetService.shared.identifyPlant(
                    image: image,
                    organ: selectedOrgan.plantNetOrgan,
                    project: project
                )
                identificationResult = result
                isIdentifying = false
            } catch {
                isIdentifying = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    /// Check if a species exists in the local SwiftData database.
    func isInLocalDatabase(_ scientificName: String, plants: [Plant]) -> Bool {
        plants.contains { $0.scientificName.lowercased() == scientificName.lowercased() }
    }

    /// Save the top identification result to the journal as a PlantObservation.
    /// Automatically captures current location from LocationManager if available.
    func saveToJournal(
        modelContext: ModelContext,
        notes: String? = nil,
        verifiedTraits: [String]? = nil
    ) {
        guard let bestMatch = identificationResult?.bestMatch else { return }

        // Capture current location (already requested during setupLocation)
        let currentLocation = LocationManager.shared.location

        let observation = PlantObservation(
            plantScientificName: bestMatch.scientificName,
            photoData: capturedImage?.jpegData(compressionQuality: 0.7),
            latitude: currentLocation?.coordinate.latitude,
            longitude: currentLocation?.coordinate.longitude,
            date: .now,
            notes: notes ?? "Identified via Capture mode with \(Int(bestMatch.score * 100))% confidence.",
            verifiedTraits: verifiedTraits ?? []
        )
        modelContext.insert(observation)
    }

    /// Reset all identification state for a fresh capture.
    func reset() {
        capturedImage = nil
        identificationResult = nil
        isIdentifying = false
        errorMessage = nil
        showError = false
    }

    /// Request location and fetch regional PlantNet project.
    func setupLocation() async {
        LocationManager.shared.requestLocation()
        await LocationManager.shared.fetchRegionalProjectIfNeeded()
    }
}
