import SwiftUI
import SwiftData

/// Compact card overlay shown at the bottom of the map when an observation pin is tapped.
struct ObservationMapCard: View {
    let observation: PlantObservation
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail — taps navigate to detail
            NavigationLink(value: observation) {
                if let photoData = observation.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                } else {
                    ZStack {
                        AppColors.cardElevated
                        Image(systemName: "leaf.fill")
                            .font(AppTypography.inter(size: 18))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }
            }
            .buttonStyle(.plain)

            // Species info — taps navigate to detail
            NavigationLink(value: observation) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(observation.plantScientificName ?? "Unidentified")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)
                        .italic(observation.plantScientificName != nil)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Label(
                            observation.date.formatted(date: .abbreviated, time: .omitted),
                            systemImage: "calendar"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)

                        if observation.latitude != nil {
                            Label(
                                String(format: "%.2f, %.2f",
                                       observation.latitude ?? 0,
                                       observation.longitude ?? 0),
                                systemImage: "location.fill"
                            )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Open in Apple Maps button
            if let lat = observation.latitude, let lon = observation.longitude {
                Button {
                    let name = observation.plantScientificName ?? "Observation"
                    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Observation"
                    if let url = URL(string: "http://maps.apple.com/?ll=\(lat),\(lon)&q=\(encoded)") {
                        openURL(url)
                    }
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.success)
                        .frame(width: 32, height: 32)
                        .background(AppColors.success.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            // Chevron for detail navigation
            NavigationLink(value: observation) {
                Image(systemName: "chevron.right")
                    .font(AppTypography.inter(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

#Preview {
    ObservationMapCard(
        observation: PlantObservation(
            plantScientificName: "Rosa canina",
            latitude: 51.5074,
            longitude: -0.1278,
            date: .now,
            notes: "Found near the riverbank"
        )
    )
    .padding()
    .background(AppColors.appBackground)
    .preferredColorScheme(.dark)
}
