import SwiftUI
import MapKit

// MARK: - Data Types

/// Annotation data for an observation pin on the map.
struct ObservationAnnotation: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String?
    let date: Date
    let hasPhoto: Bool

    static func == (lhs: ObservationAnnotation, rhs: ObservationAnnotation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Bounding box overlay for region visualization.
struct RegionOverlay {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    var corners: [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon), // top-left
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon), // top-right
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon), // bottom-right
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon), // bottom-left
        ]
    }

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.3,
                longitudeDelta: (maxLon - minLon) * 1.3
            )
        )
    }
}

// MARK: - BotanyMapView

/// Reusable MapKit wrapper with satellite imagery and dark-mode-friendly styling.
/// Used by ObservationMapView and RegionMapView.
struct BotanyMapView: View {
    @Binding var cameraPosition: MapCameraPosition
    let annotations: [ObservationAnnotation]
    let regionOverlay: RegionOverlay?
    var selectedAnnotationID: String?
    var onAnnotationTap: ((ObservationAnnotation) -> Void)?

    var body: some View {
        Map(position: $cameraPosition) {
            // User location
            UserAnnotation()

            // Observation pins
            ForEach(annotations) { annotation in
                Annotation(
                    annotation.title,
                    coordinate: annotation.coordinate
                ) {
                    ObservationMapPin(
                        hasPhoto: annotation.hasPhoto,
                        isSelected: annotation.id == selectedAnnotationID
                    )
                    .onTapGesture {
                        onAnnotationTap?(annotation)
                    }
                }
            }

            // Region bounding box overlay
            if let region = regionOverlay {
                MapPolygon(coordinates: region.corners)
                    .foregroundStyle(AppColors.success.opacity(0.08))
                    .stroke(AppColors.success.opacity(0.4), lineWidth: 1.5)
            }
        }
        .mapStyle(.imagery(elevation: .flat))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }
}

// MARK: - ObservationMapPin

/// Custom annotation pin view styled to match the app's DesignSystem.
struct ObservationMapPin: View {
    let hasPhoto: Bool
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? AppColors.primaryAmber : AppColors.success)
                    .frame(width: 32, height: 32)
                    .shadow(
                        color: (isSelected ? AppColors.primaryAmber : AppColors.success).opacity(0.5),
                        radius: isSelected ? 6 : 4,
                        y: 2
                    )

                Image(systemName: hasPhoto ? "camera.fill" : "leaf.fill")
                    .font(AppTypography.inter(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Pin stem
            Image(systemName: "triangle.fill")
                .font(AppTypography.inter(size: 10))
                .foregroundStyle(isSelected ? AppColors.primaryAmber : AppColors.success)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}

#Preview {
    BotanyMapView(
        cameraPosition: .constant(.automatic),
        annotations: [
            ObservationAnnotation(
                id: "1",
                coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                title: "Rosa canina",
                subtitle: "Dog Rose",
                date: .now,
                hasPhoto: true
            ),
            ObservationAnnotation(
                id: "2",
                coordinate: CLLocationCoordinate2D(latitude: 51.51, longitude: -0.13),
                title: "Quercus robur",
                subtitle: "English Oak",
                date: .now,
                hasPhoto: false
            )
        ],
        regionOverlay: nil
    )
    .preferredColorScheme(.dark)
}
