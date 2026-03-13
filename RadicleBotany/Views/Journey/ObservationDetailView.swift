import SwiftUI
import SwiftData
import MapKit

struct ObservationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Bindable var observation: PlantObservation

    @Query private var allPlants: [Plant]

    @State private var editableNotes: String = ""
    @State private var showDeleteConfirmation = false

    private var matchedPlant: Plant? {
        guard let name = observation.plantScientificName else { return nil }
        return allPlants.first { $0.scientificName == name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photoSection
                speciesSection
                locationSection
                dateSection
                traitsSection
                notesSection
                deleteSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editableNotes = observation.notes ?? ""
        }
        .alert("Delete Observation", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteObservation()
            }
        } message: {
            Text("Are you sure you want to delete this observation? This action cannot be undone.")
        }
    }

    // MARK: - Photo Section

    @ViewBuilder
    private var photoSection: some View {
        if let photoData = observation.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
        } else {
            ZStack {
                AppColors.cardElevated
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(AppTypography.inter(size: 40))
                        .foregroundStyle(AppColors.textMuted)
                    Text("No photo")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Species Section

    @ViewBuilder
    private var speciesSection: some View {
        if let scientificName = observation.plantScientificName {
            VStack(alignment: .leading, spacing: 8) {
                Text("SPECIES")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.primaryAmber)

                if let plant = matchedPlant {
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scientificName)
                                    .font(AppTypography.buttonText)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .italic()

                                Text(plant.titleCasedCommonName)
                                    .font(AppTypography.bodyText)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(AppTypography.inter(size: 12))
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(scientificName)
                        .font(AppTypography.buttonText)
                        .foregroundStyle(AppColors.textPrimary)
                        .italic()
                }
            }
            .padding(AppSpacing.sectionPadding)
            .cardStyle(elevated: false, interactive: matchedPlant != nil)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("SPECIES")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.primaryAmber)

                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(AppColors.textMuted)
                    Text("Unidentified")
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.sectionPadding)
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCATION")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.primaryAmber)

            if let latitude = observation.latitude, let longitude = observation.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                // Mini map preview
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 500,
                    longitudinalMeters: 500
                ))) {
                    Annotation("", coordinate: coordinate) {
                        ObservationMapPin(hasPhoto: observation.photoData != nil)
                    }
                }
                .mapStyle(.imagery(elevation: .flat))
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                .allowsHitTesting(false)

                // Coordinate text + Open in Maps
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(AppTypography.inter(size: 12))
                            .foregroundStyle(AppColors.primaryAmber)

                        Text(String(format: "%.6f, %.6f", latitude, longitude))
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textMuted)
                    }

                    Spacer()

                    Button {
                        openInMaps(latitude: latitude, longitude: longitude)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(AppTypography.inter(size: 11))
                            Text("Open in Maps")
                                .font(AppTypography.caption)
                        }
                        .foregroundStyle(AppColors.primaryAmber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColors.primaryAmber.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.textMuted)
                    Text("No location recorded")
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.sectionPadding)
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATE & TIME")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.primaryAmber)

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(AppColors.primaryAmber)

                VStack(alignment: .leading, spacing: 2) {
                    Text(observation.date.formatted(date: .long, time: .omitted))
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(observation.date.formatted(date: .omitted, time: .standard))
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                }
            }
        }
        .padding(AppSpacing.sectionPadding)
    }

    // MARK: - Traits Section

    @ViewBuilder
    private var traitsSection: some View {
        if !observation.verifiedTraits.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("VERIFIED TRAITS")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.primaryAmber)

                FlowLayout(spacing: 8) {
                    ForEach(observation.verifiedTraits, id: \.self) { trait in
                        CategoryPill(text: trait, color: .orangePrimary)
                    }
                }
            }
            .padding(AppSpacing.sectionPadding)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.primaryAmber)

            TextField("Add notes about this observation...", text: $editableNotes, axis: .vertical)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(3...8)
                .textFieldStyle(.plain)
                .onChange(of: editableNotes) { _, newValue in
                    observation.notes = newValue.isEmpty ? nil : newValue
                }
        }
        .padding(AppSpacing.sectionPadding)
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Delete Observation")
            }
            .font(AppTypography.sectionHeader)
            .foregroundStyle(AppColors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.error.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
    }

    // MARK: - Actions

    private func openInMaps(latitude: Double, longitude: Double) {
        let name = observation.plantScientificName ?? "Observation"
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Observation"
        if let url = URL(string: "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(encoded)") {
            openURL(url)
        }
    }

    private func deleteObservation() {
        modelContext.delete(observation)
        dismiss()
    }
}

// MARK: - Flow Layout for Trait Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    NavigationStack {
        ObservationDetailView(
            observation: PlantObservation(
                plantScientificName: "Rosa canina",
                latitude: 51.5074,
                longitude: -0.1278,
                date: .now,
                notes: "Found near the riverbank",
                verifiedTraits: ["Simple leaves", "Alternate", "Prickly stem"]
            )
        )
    }
    .modelContainer(for: [PlantObservation.self, Plant.self], inMemory: true)
}
