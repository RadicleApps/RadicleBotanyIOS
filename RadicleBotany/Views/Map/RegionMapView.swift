import SwiftUI
import MapKit

/// Map view showing the user's geographic bounding box for Plants Near Me predictions.
/// Displays a semi-transparent overlay of the 25km search radius.
struct RegionMapView: View {
    let boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)
    let predictionCount: Int
    let databaseMatchCount: Int
    let topSpecies: [String]

    @State private var cameraPosition: MapCameraPosition

    init(
        boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double),
        predictionCount: Int,
        databaseMatchCount: Int,
        topSpecies: [String]
    ) {
        self.boundingBox = boundingBox
        self.predictionCount = predictionCount
        self.databaseMatchCount = databaseMatchCount
        self.topSpecies = topSpecies

        let overlay = RegionOverlay(
            minLat: boundingBox.minLat,
            maxLat: boundingBox.maxLat,
            minLon: boundingBox.minLon,
            maxLon: boundingBox.maxLon
        )
        _cameraPosition = State(initialValue: .region(overlay.region))
    }

    private var overlay: RegionOverlay {
        RegionOverlay(
            minLat: boundingBox.minLat,
            maxLat: boundingBox.maxLat,
            minLon: boundingBox.minLon,
            maxLon: boundingBox.maxLon
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map with bounding box overlay
            BotanyMapView(
                cameraPosition: $cameraPosition,
                annotations: [],
                regionOverlay: overlay,
                onAnnotationTap: nil
            )
            .ignoresSafeArea(edges: .bottom)

            // Bottom info panel
            infoPanel
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Info Panel

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Label("Search Region", systemImage: "location.viewfinder")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.success)

                Spacer()

                Text("25 km radius")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            // Stats row
            HStack(spacing: 16) {
                statItem(
                    value: "\(predictionCount)",
                    label: "Predicted",
                    color: .greenSecondary
                )

                statItem(
                    value: "\(databaseMatchCount)",
                    label: "In Database",
                    color: .orangePrimary
                )
            }

            // Top species
            if !topSpecies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOP SPECIES")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)

                    Text(topSpecies.prefix(3).joined(separator: " · "))
                        .font(AppTypography.fieldLabel)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(AppTypography.buttonText)
                .foregroundStyle(color)

            Text(label)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
    }
}

#Preview {
    RegionMapView(
        boundingBox: (minLat: 51.28, maxLat: 51.73, minLon: -0.35, maxLon: 0.10),
        predictionCount: 47,
        databaseMatchCount: 12,
        topSpecies: ["Quercus robur", "Betula pendula", "Acer pseudoplatanus"]
    )
    .preferredColorScheme(.dark)
}
