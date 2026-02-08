import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PlantIdentificationViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .padding()
                } else {
                    PlaceholderView()
                }

                if viewModel.isLoading {
                    ProgressView("Identifying plant...")
                }

                if let result = viewModel.identificationResult {
                    PlantResultView(result: result)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                HStack(spacing: 16) {
                    Button {
                        viewModel.showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.showPhotoPicker = true
                    } label: {
                        Label("Photos", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Radicle Botany")
            .sheet(isPresented: $viewModel.showPhotoPicker) {
                PhotoPickerView(image: $viewModel.selectedImage)
            }
            .sheet(isPresented: $viewModel.showCamera) {
                CameraView(image: $viewModel.selectedImage)
            }
            .onChange(of: viewModel.selectedImage) {
                if viewModel.selectedImage != nil {
                    viewModel.identifyPlant()
                }
            }
        }
    }
}

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("Take or select a photo to identify a plant")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: 300)
    }
}

#Preview {
    ContentView()
}
