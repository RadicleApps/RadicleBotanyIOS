import SwiftUI
import SwiftData

// MARK: - IdentificationViewModel

/// Shared ViewModel for Capture and Both modes.
/// Handles PlantNet API identification, organ selection, results, and journal saving.
@MainActor
class IdentificationViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var selectedOrgan: CaptureOrgan = .flower
    @Published var isIdentifying = false
    @Published var identificationResult: PlantIdentificationResult?
    @Published var showResults = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showCamera = false
    @Published var showPhotoPicker = false

    // Local database reference
    @Published var plants: [Plant] = []

    func loadPlants(from context: ModelContext) {
        plants = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
    }

    // MARK: - Identification

    func identifyImage() {
        guard let image = capturedImage else { return }
        identificationResult = nil
        isIdentifying = true

        Task {
            do {
                let result = try await PlantNetService.shared.identifyPlant(
                    image: image,
                    organ: selectedOrgan.plantNetOrgan
                )
                identificationResult = result
                isIdentifying = false
                if !result.results.isEmpty {
                    showResults = true
                }
            } catch {
                isIdentifying = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    // MARK: - Common Names

    /// Returns all common names for a match, safely unwrapping the optional array.
    func allCommonNames(for match: PlantMatch) -> [String] {
        match.species.commonNames ?? []
    }

    /// Returns a display string of common names (comma-separated).
    func commonNamesDisplay(for match: PlantMatch) -> String {
        let names = allCommonNames(for: match)
        if names.isEmpty {
            return match.species.scientificNameWithoutAuthor
        }
        return names.prefix(3).joined(separator: ", ")
    }

    // MARK: - Database Lookup

    func isInLocalDatabase(_ scientificName: String) -> Bool {
        plants.contains { $0.scientificName.lowercased() == scientificName.lowercased() }
    }

    func localPlant(for scientificName: String) -> Plant? {
        plants.first { $0.scientificName.lowercased() == scientificName.lowercased() }
    }

    // MARK: - Reset

    func reset() {
        capturedImage = nil
        identificationResult = nil
        isIdentifying = false
        showResults = false
        errorMessage = nil
        showError = false
    }

    func retake() {
        capturedImage = nil
        identificationResult = nil
    }

    // MARK: - Save to Journal

    func saveToJournal(context: ModelContext, verifiedTraits: [String] = []) {
        guard let bestMatch = identificationResult?.bestMatch else { return }

        let observation = PlantObservation(
            plantScientificName: bestMatch.scientificName,
            photoData: capturedImage?.jpegData(compressionQuality: 0.7),
            date: .now,
            notes: "Identified via \(verifiedTraits.isEmpty ? "Capture" : "Both") mode with \(Int(bestMatch.score * 100))% confidence.",
            verifiedTraits: verifiedTraits
        )
        context.insert(observation)
    }

    func saveBothModeToJournal(context: ModelContext, adjustedMatch: BothModeAdjustedMatch?, verifiedTraits: [String: String]) {
        guard let result = identificationResult,
              let bestMatch = result.bestMatch else { return }

        let topName = adjustedMatch?.match.scientificName ?? bestMatch.scientificName
        let topScore = adjustedMatch?.adjustedScore ?? bestMatch.score

        let observation = PlantObservation(
            plantScientificName: topName,
            photoData: capturedImage?.jpegData(compressionQuality: 0.7),
            date: .now,
            notes: "Identified via Both mode. Original: \(Int(bestMatch.score * 100))%, Adjusted: \(Int(topScore * 100))%. Verified \(verifiedTraits.count) traits.",
            verifiedTraits: Array(verifiedTraits.values)
        )
        context.insert(observation)
    }
}

// MARK: - Both Mode Adjusted Match

struct BothModeAdjustedMatch {
    let match: PlantMatch
    let adjustedScore: Double
    let verifiedTraitCount: Int
}
