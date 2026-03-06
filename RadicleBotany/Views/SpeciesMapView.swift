import SwiftUI
import MapKit

// MARK: - Species Distribution Map

struct SpeciesMapView: View {
    let plant: Plant
    let userObservations: [PlantObservation]

    @State private var occurrences: [GBIFOccurrenceCoordinate] = []
    @State private var totalCount: Int = 0
    @State private var isLoading = false
    @State private var hasFetched = false
    @State private var resolveFailed = false
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            // Map
            ZStack {
                if resolveFailed && !isLoading {
                    emptyState(icon: "globe", message: "No distribution data available for this species")
                } else {
                    mapContent
                }

                if isLoading {
                    loadingOverlay
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

            // Stats footer
            if hasFetched && !isLoading {
                statsFooter
            }
        }
        .task {
            await loadOccurrences()
        }
    }

    // MARK: - Map Content

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            // GBIF occurrence pins (clustered)
            ForEach(clusteredOccurrences) { cluster in
                Annotation("", coordinate: cluster.coordinate) {
                    OccurrenceClusterPin(count: cluster.count, isUserData: false)
                }
            }

            // User observation pins
            ForEach(userAnnotations) { annotation in
                Annotation(annotation.title, coordinate: annotation.coordinate) {
                    OccurrenceClusterPin(count: 1, isUserData: true)
                }
            }
        }
        .mapStyle(.imagery(elevation: .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Clustering

    private var clusteredOccurrences: [ClusteredOccurrence] {
        guard !occurrences.isEmpty else { return [] }

        // Round to 1 decimal place (~11km grid)
        var groups: [String: [GBIFOccurrenceCoordinate]] = [:]
        for occ in occurrences {
            let key = "\(round(occ.latitude * 10) / 10),\(round(occ.longitude * 10) / 10)"
            groups[key, default: []].append(occ)
        }

        return groups.map { _, members in
            let avgLat = members.map(\.latitude).reduce(0, +) / Double(members.count)
            let avgLon = members.map(\.longitude).reduce(0, +) / Double(members.count)
            return ClusteredOccurrence(
                id: "\(avgLat),\(avgLon)",
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                count: members.count
            )
        }
    }

    private var userAnnotations: [ObservationAnnotation] {
        userObservations.compactMap { obs in
            guard let lat = obs.latitude, let lon = obs.longitude else { return nil }
            return ObservationAnnotation(
                id: "user-\(obs.date.timeIntervalSince1970)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                title: plant.commonName,
                subtitle: obs.notes,
                date: obs.date,
                hasPhoto: obs.photoData != nil
            )
        }
    }

    // MARK: - Stats Footer

    private var statsFooter: some View {
        HStack(spacing: 12) {
            if totalCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "globe.americas.fill")
                        .font(AppTypography.inter(size: 10))
                        .foregroundStyle(AppColors.success)
                    Text(formatCount(totalCount) + " observations worldwide")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if !userObservations.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(AppTypography.inter(size: 10))
                        .foregroundStyle(AppColors.primaryAmber)
                    Text("\(userObservations.count) your observation\(userObservations.count == 1 ? "" : "s")")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if totalCount == 0 && userObservations.isEmpty {
                Text("No occurrence records found")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Loading & Empty States

    private var loadingOverlay: some View {
        ZStack {
            AppColors.appBackground.opacity(0.6)
            VStack(spacing: 8) {
                ProgressView()
                    .tint(AppColors.success)
                Text("Loading distribution data...")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
    }

    private func emptyState(icon: String, message: String) -> some View {
        ZStack {
            AppColors.cardBackground
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(AppTypography.inter(size: 24))
                    .foregroundStyle(AppColors.textMuted.opacity(0.4))
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Data Loading

    private func loadOccurrences() async {
        guard !hasFetched else { return }

        isLoading = true

        // Use existing gbifId or resolve it dynamically via GBIF Species Match API
        var speciesKey = plant.gbifId
        if speciesKey == nil {
            speciesKey = await GBIFOccurrenceService.shared.resolveSpeciesKey(scientificName: plant.scientificName)
            // Cache the resolved ID on the plant model for future use
            if let resolved = speciesKey {
                plant.gbifId = resolved
            }
        }

        guard let gbifId = speciesKey else {
            isLoading = false
            hasFetched = true
            resolveFailed = true
            return
        }

        let result = await GBIFOccurrenceService.shared.fetchOccurrences(gbifId: gbifId)
        occurrences = result.occurrences
        totalCount = result.totalCount
        isLoading = false
        hasFetched = true
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Clustered Occurrence

struct ClusteredOccurrence: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
}

// MARK: - Occurrence Cluster Pin

struct OccurrenceClusterPin: View {
    let count: Int
    let isUserData: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isUserData ? AppColors.primaryAmber : AppColors.success.opacity(0.85))
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)

            if count > 1 {
                Text("\(count)")
                    .font(AppTypography.inter(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: isUserData ? "leaf.fill" : "circle.fill")
                    .font(AppTypography.inter(size: 7))
                    .foregroundStyle(.white)
            }
        }
    }

    private var badgeSize: CGFloat {
        count > 99 ? 32 : count > 9 ? 28 : count > 1 ? 24 : 14
    }

    private var fontSize: CGFloat {
        count > 99 ? 10 : count > 9 ? 9 : 8
    }
}
