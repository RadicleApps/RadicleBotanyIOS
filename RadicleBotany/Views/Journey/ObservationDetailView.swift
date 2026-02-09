import SwiftUI
import SwiftData

struct ObservationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var observation: Observation

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
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("Observation")
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
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderSubtle, lineWidth: 0.5)
                )
        } else {
            ZStack {
                Color.surfaceElevated
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.textMuted)
                    Text("No photo")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Species Section

    @ViewBuilder
    private var speciesSection: some View {
        if let scientificName = observation.plantScientificName {
            VStack(alignment: .leading, spacing: 8) {
                Text("SPECIES")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)

                if let plant = matchedPlant {
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(scientificName)
                                    .font(AppFont.sectionHeader(16))
                                    .foregroundStyle(Color.textPrimary)
                                    .italic()

                                Text(plant.commonName)
                                    .font(AppFont.body())
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(scientificName)
                        .font(AppFont.sectionHeader(16))
                        .foregroundStyle(Color.textPrimary)
                        .italic()
                }
            }
            .cardStyle()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("SPECIES")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)

                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.textMuted)
                    Text("Unidentified")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCATION")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)

            if let latitude = observation.latitude, let longitude = observation.longitude {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.greenSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.6f, %.6f", latitude, longitude))
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)

                        Text("Lat / Long")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textMuted)
                    Text("No location recorded")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATE & TIME")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.purpleSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(observation.date.formatted(date: .long, time: .omitted))
                        .font(AppFont.body())
                        .foregroundStyle(Color.textPrimary)

                    Text(observation.date.formatted(date: .omitted, time: .standard))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Traits Section

    @ViewBuilder
    private var traitsSection: some View {
        if !observation.verifiedTraits.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("VERIFIED TRAITS")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)

                FlowLayout(spacing: 8) {
                    ForEach(observation.verifiedTraits, id: \.self) { trait in
                        CategoryPill(text: trait, color: .greenSecondary)
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)

            TextField("Add notes about this observation...", text: $editableNotes, axis: .vertical)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(3...8)
                .textFieldStyle(.plain)
                .onChange(of: editableNotes) { _, newValue in
                    observation.notes = newValue.isEmpty ? nil : newValue
                }
        }
        .cardStyle()
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
            .font(AppFont.sectionHeader())
            .foregroundStyle(Color.errorRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.errorRed.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

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
            observation: Observation(
                plantScientificName: "Rosa canina",
                latitude: 51.5074,
                longitude: -0.1278,
                date: .now,
                notes: "Found near the riverbank",
                verifiedTraits: ["Simple leaves", "Alternate", "Prickly stem"]
            )
        )
    }
    .modelContainer(for: [Observation.self, Plant.self], inMemory: true)
}
