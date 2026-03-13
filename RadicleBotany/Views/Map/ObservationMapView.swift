import SwiftUI
import SwiftData
import MapKit

/// Full-screen map view showing all geolocated observations as pins.
/// Accessed from the Journal tab's stats header.
struct ObservationMapView: View {
    @Query(sort: \PlantObservation.date, order: .reverse)
    private var allObservations: [PlantObservation]

    @ObservedObject private var locationManager = LocationManager.shared

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedAnnotation: ObservationAnnotation?
    @State private var selectedObservation: PlantObservation?

    /// Observations that have valid coordinates
    private var geoObservations: [PlantObservation] {
        allObservations.filter { $0.latitude != nil && $0.longitude != nil }
    }

    /// Convert observations to map annotations
    private var annotations: [ObservationAnnotation] {
        geoObservations.enumerated().map { index, obs in
            ObservationAnnotation(
                id: "\(index)-\(obs.date.timeIntervalSince1970)",
                coordinate: CLLocationCoordinate2D(
                    latitude: obs.latitude ?? 0,
                    longitude: obs.longitude ?? 0
                ),
                title: obs.plantScientificName ?? "Unidentified",
                subtitle: obs.date.formatted(date: .abbreviated, time: .omitted),
                date: obs.date,
                hasPhoto: obs.photoData != nil
            )
        }
    }

    private var unmappedCount: Int {
        allObservations.count - geoObservations.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if geoObservations.isEmpty {
                emptyState
            } else {
                // Map
                BotanyMapView(
                    cameraPosition: $cameraPosition,
                    annotations: annotations,
                    regionOverlay: nil,
                    selectedAnnotationID: selectedAnnotation?.id,
                    onAnnotationTap: { annotation in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAnnotation = annotation
                            // Extract index from annotation id ("index-timestamp")
                            if let dashIndex = annotation.id.firstIndex(of: "-"),
                               let index = Int(annotation.id[..<dashIndex]),
                               index < geoObservations.count {
                                selectedObservation = geoObservations[index]
                            }
                        }
                    }
                )
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedAnnotation = nil
                        selectedObservation = nil
                    }
                }

                // Bottom overlays
                VStack(spacing: 8) {
                    // Stats pill
                    statsPill

                    // Selected observation card
                    if let observation = selectedObservation {
                        ObservationMapCard(observation: observation)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PlantObservation.self) { observation in
            ObservationDetailView(observation: observation)
        }
        .onAppear {
            setupInitialCamera()
        }
    }

    // MARK: - Stats Pill

    private var statsPill: some View {
        HStack(spacing: 8) {
            Label("\(geoObservations.count) mapped", systemImage: "mappin.circle.fill")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.success)

            if unmappedCount > 0 {
                Text("·")
                    .foregroundStyle(AppColors.textMuted)

                Text("\(unmappedCount) without location")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("No Mapped Observations")
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            if allObservations.isEmpty {
                Text("Head to Botanize to capture your first plant observation. Observations with location data will appear here on the map.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("You have \(allObservations.count) observation\(allObservations.count == 1 ? "" : "s"), but none have location data. Enable location services when saving observations to see them on the map.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func setupInitialCamera() {
        if !annotations.isEmpty {
            cameraPosition = .automatic
        } else if let location = locationManager.location {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            ))
        }
    }
}

#Preview {
    NavigationStack {
        ObservationMapView()
    }
    .modelContainer(for: [PlantObservation.self, Plant.self], inMemory: true)
    .preferredColorScheme(.dark)
}
