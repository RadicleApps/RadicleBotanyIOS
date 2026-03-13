import SwiftUI
import SwiftData
import MapKit

struct JournalView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlantObservation.date, order: .reverse)
    private var observations: [PlantObservation]

    @Query private var userSettingsResults: [UserSettings]

    @Query(sort: \JournalNote.date, order: .reverse)
    private var journalNotes: [JournalNote]

    @State private var selectedNote: JournalNote? = nil

    private var userSettings: UserSettings? {
        userSettingsResults.first
    }

    private var streakCount: Int {
        userSettings?.streakCount ?? 0
    }

    private var mostRecentObservation: PlantObservation? {
        observations.first
    }

    private var earlierObservations: [PlantObservation] {
        Array(observations.dropFirst().prefix(10))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                paidUserContent
            }

            // Floating new note button
            Button {
                createAndOpenNote()
            } label: {
                Image(systemName: "plus")
                    .font(AppTypography.inter(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(AppColors.primaryAmber)
                    .clipShape(Circle())
                    .shadow(color: AppColors.primaryAmber.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationDestination(for: PlantObservation.self) { observation in
            ObservationDetailView(observation: observation)
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                NoteEditorView(
                    note: note,
                    isNewNote: note.title.isEmpty && note.content.isEmpty,
                    onDelete: {
                        modelContext.delete(note)
                        selectedNote = nil
                    }
                )
            }
        }
    }

    // MARK: - Paid User Content

    // Observations with valid coordinates for map
    private var geoObservations: [PlantObservation] {
        observations.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var paidUserContent: some View {
        VStack(spacing: 20) {
            statsHeader
            heroObservationCard
            mapPreviewCard
            earlierObservationsSection
            notesSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 140)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if streakCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(AppColors.primaryAmber)
                        Text("\(streakCount) day streak")
                            .font(AppTypography.buttonText)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                } else {
                    Text("Start your journal")
                        .font(AppTypography.buttonText)
                        .foregroundStyle(AppColors.textPrimary)
                }

                Text("\(observations.count) observation\(observations.count == 1 ? "" : "s") total")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()

            NavigationLink {
                ObservationMapView()
            } label: {
                Image(systemName: "map.fill")
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(AppColors.primaryAmber)
                    .frame(width: 34, height: 34)
                    .background(AppColors.primaryAmber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            }
        }
        .padding(AppSpacing.sectionPadding)
        .cardStyle()
    }

    // MARK: - Map Preview Card

    @ViewBuilder
    private var mapPreviewCard: some View {
        if !geoObservations.isEmpty {
            NavigationLink {
                ObservationMapView()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text("YOUR OBSERVATIONS")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.primaryAmber)
                        .padding(.bottom, 10)

                    ZStack(alignment: .bottom) {
                        // Mini map with observation pins
                        Map(initialPosition: mapPreviewPosition) {
                            ForEach(Array(geoObservations.prefix(50).enumerated()), id: \.element.date) { _, obs in
                                if let lat = obs.latitude, let lon = obs.longitude {
                                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                                        Circle()
                                            .fill(AppColors.primaryAmber)
                                            .frame(width: 10, height: 10)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                                            )
                                            .shadow(color: AppColors.primaryAmber.opacity(0.4), radius: 3, y: 1)
                                    }
                                }
                            }
                        }
                        .mapStyle(.imagery(elevation: .flat))
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                        .allowsHitTesting(false)

                        // Bottom gradient overlay with label
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(AppTypography.inter(size: 12))
                                    .foregroundStyle(AppColors.primaryAmber)

                                Text("\(geoObservations.count) mapped")
                                    .font(AppTypography.tagText)
                                    .foregroundStyle(AppColors.textPrimary)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Text("View Map")
                                    .font(AppTypography.tagText)
                                    .foregroundStyle(AppColors.primaryAmber)

                                Image(systemName: "chevron.right")
                                    .font(AppTypography.inter(size: 9, weight: .semibold))
                                    .foregroundStyle(AppColors.primaryAmber)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.clear, AppColors.appBackground.opacity(0.85), AppColors.appBackground],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(AppColors.border, lineWidth: 0.5)
                    )
                }
            }
            .buttonStyle(.plain)
        } else if !observations.isEmpty {
            // Has observations but none with location
            NavigationLink {
                ObservationMapView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.primaryAmber)
                        .frame(width: 36, height: 36)
                        .background(AppColors.primaryAmber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Observation Map")
                            .font(AppTypography.buttonText)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Enable location to map your finds")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(AppTypography.inter(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(14)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// Compute a camera position that fits all geolocated observations
    private var mapPreviewPosition: MapCameraPosition {
        guard !geoObservations.isEmpty else { return .automatic }

        let lats = geoObservations.compactMap(\.latitude)
        let lons = geoObservations.compactMap(\.longitude)

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return .automatic
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.4, 0.01)
        let spanLon = max((maxLon - minLon) * 1.4, 0.01)

        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        ))
    }

    // MARK: - Hero Observation Card

    @ViewBuilder
    private var heroObservationCard: some View {
        if let observation = mostRecentObservation {
            VStack(alignment: .leading, spacing: 0) {
                Text("LATEST OBSERVATION")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.primaryAmber)
                    .padding(.bottom, 10)

                NavigationLink(value: observation) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let photoData = observation.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 12,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 12
                                    )
                                )
                        } else {
                            ZStack {
                                AppColors.cardElevated
                                Image("Trillium")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 140)
                                    .opacity(0.15)
                            }
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 12,
                                    bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 12
                                )
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(observation.plantScientificName ?? "Unidentified")
                                .font(AppTypography.buttonText)
                                .foregroundStyle(AppColors.textPrimary)
                                .italic(observation.plantScientificName != nil)

                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(AppTypography.inter(size: 10))
                                    Text(observation.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(AppTypography.tagText)
                                }
                                .foregroundStyle(AppColors.textMuted)

                                if let lat = observation.latitude, let lon = observation.longitude {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(AppTypography.inter(size: 10))
                                        Text(String(format: "%.4f, %.4f", lat, lon))
                                            .font(AppTypography.tagText)
                                    }
                                    .foregroundStyle(AppColors.textMuted)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 12,
                                bottomTrailingRadius: 12,
                                topTrailingRadius: 0
                            )
                        )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(AppColors.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        } else {
            VStack(spacing: 16) {
                Image("Sequential Morphology of Emergence")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .opacity(0.7)

                VStack(spacing: 6) {
                    Text("No observations yet")
                        .font(AppTypography.headerTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Head to Botanize to capture your first plant observation.")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, AppSpacing.sectionPadding)
        }
    }

    // MARK: - Earlier Observations

    @ViewBuilder
    private var earlierObservationsSection: some View {
        if earlierObservations.count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("RECENT")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.primaryAmber)

                    Spacer()

                    NavigationLink {
                        ObservationsListView()
                    } label: {
                        Text("See All")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.primaryAmber)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(earlierObservations) { observation in
                            NavigationLink(value: observation) {
                                earlierObservationCard(observation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func earlierObservationCard(_ observation: PlantObservation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let photoData = observation.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 100)
                    .clipped()
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 10,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 10
                        )
                    )
            } else {
                ZStack {
                    AppColors.cardElevated
                    Image(systemName: "leaf.fill")
                        .font(AppTypography.inter(size: 20))
                        .foregroundStyle(AppColors.textMuted)
                }
                .frame(width: 140, height: 100)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 10,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 10
                    )
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(observation.plantScientificName ?? "Unidentified")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(observation.date.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(8)
            .frame(width: 140, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 10,
                    topTrailingRadius: 0
                )
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text("NOTES")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.primaryAmber)

                Spacer()

                if !journalNotes.isEmpty {
                    NavigationLink {
                        NotesListView()
                    } label: {
                        Text("See All")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.primaryAmber)
                    }
                }
            }

            if journalNotes.isEmpty {
                // Empty state — single tappable row
                Button {
                    createAndOpenNote()
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start a note")
                                .font(AppTypography.buttonText)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Field notes, reflections, observations...")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textMuted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "plus.circle.fill")
                            .font(AppTypography.inter(size: 16))
                            .foregroundStyle(AppColors.primaryAmber)
                    }
                    .padding(14)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .stroke(AppColors.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            } else {
                // Note preview cards — horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // New note button
                        Button {
                            createAndOpenNote()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(AppTypography.inter(size: 18, weight: .semibold))
                                    .foregroundStyle(AppColors.primaryAmber)

                                Text("New")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            .frame(width: 60, height: 110)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.card)
                                    .stroke(
                                        AppColors.primaryAmber.opacity(0.3),
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        // Note cards
                        ForEach(journalNotes.prefix(6)) { note in
                            Button {
                                selectedNote = note
                            } label: {
                                notePreviewCard(note)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func notePreviewCard(_ note: JournalNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(note.displayTitle)
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            // Content snippet
            Text(note.content.isEmpty ? "No content" : note.content)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Spacer()

            // Bottom: date + optional link pill
            HStack(spacing: 4) {
                if let entityType = note.entityType {
                    Image(systemName: entityType.icon)
                        .font(AppTypography.inter(size: 8))
                        .foregroundStyle(entityType.color)
                }

                Text(note.date.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(10)
        .frame(width: 150, height: 110, alignment: .topLeading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func createAndOpenNote() {
        let newNote = JournalNote()
        modelContext.insert(newNote)
        selectedNote = newNote
    }

}

#Preview {
    NavigationStack {
        JournalView()
            .environmentObject(StoreManager(preview: true))
            .modelContainer(for: [PlantObservation.self, UserSettings.self, JournalNote.self], inMemory: true)
    }
}
