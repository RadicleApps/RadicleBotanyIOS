import SwiftUI

@MainActor
class PlantIdentificationViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var identificationResult: PlantIdentificationResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showPhotoPicker = false
    @Published var showCamera = false

    private let service = PlantNetService.shared

    func identifyPlant() {
        guard let image = selectedImage else { return }

        isLoading = true
        errorMessage = nil
        identificationResult = nil

        Task {
            do {
                let result = try await service.identifyPlant(image: image)
                identificationResult = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
