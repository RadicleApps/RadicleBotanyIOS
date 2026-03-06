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

    @State private var activeCollectionPrompt: CollectionType? = nil
    @State private var selectedNote: JournalNote? = nil

    var onLogObservation: (() -> Void)? = nil

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
            collectionsSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 100)
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
                            .font(AppTypography.sectionHeader)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppColors.primaryAmber)
                        Text("Start your journal")
                            .font(AppTypography.sectionHeader)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }

                Text("\(observations.count) observation\(observations.count == 1 ? "" : "s") total")
                    .font(AppTypography.tagText)
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
                        .foregroundStyle(AppColors.textMuted)
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
                            .font(AppTypography.sectionHeader)
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
                    .foregroundStyle(AppColors.textMuted)
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
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Head to Botanize to capture your first plant observation.")
                        .font(AppTypography.tagText)
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
                        .foregroundStyle(AppColors.textMuted)

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
                    .font(AppTypography.tagText)
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
                    .foregroundStyle(AppColors.textMuted)

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
                        Image(systemName: "pencil.and.outline")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.primaryAmber)
                            .frame(width: 36, height: 36)
                            .background(AppColors.primaryAmber.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start a note")
                                .font(AppTypography.sectionHeader)
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

    // MARK: - Collections Section

    private var collectionsSection: some View {
        VStack(spacing: 8) {
            // Section header with help
            HStack {
                Text("COLLECTIONS")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.textMuted)
                    .kerning(2)

                Spacer()

                InfoButton(guide: .collections, style: .inline)
            }
            .padding(.bottom, 4)

            ForEach(CollectionType.allCases) { type in
                collectionRow(type: type)
            }

            Button {
                activeCollectionPrompt = .custom
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(AppTypography.inter(size: 16))
                    Text("New Collection")
                        .font(AppTypography.sectionHeader)
                }
            }
            .buttonStyle(SecondaryButtonStyle(color: .orangePrimary))
            .padding(.top, 4)
        }
        .sheet(item: $activeCollectionPrompt) { type in
            collectionEmptySheet(type)
        }
    }

    private func collectionRow(type: CollectionType) -> some View {
        Button {
            activeCollectionPrompt = type
        } label: {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(type.color)
                    .frame(width: 36, height: 36)
                    .background(type.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                VStack(alignment: .leading, spacing: 3) {
                    Text(type.name)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(type.subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(1)
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

    // MARK: - Collection Empty Sheet

    private func collectionEmptySheet(_ type: CollectionType) -> some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(AppColors.textMuted.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Hero illustration
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.08))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(type.color.opacity(0.05))
                    .frame(width: 160, height: 160)

                Image(systemName: type.icon)
                    .font(AppTypography.inter(size: 40))
                    .foregroundStyle(type.color.opacity(0.6))
            }
            .padding(.bottom, 28)

            // Title
            Text(type.emptyTitle)
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            // Description
            Text(type.emptyMessage)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            // How-to steps
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(type.emptySteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(AppTypography.tagText)
                            .fontWeight(.bold)
                            .foregroundStyle(type.color)
                            .frame(width: 24, height: 24)
                            .background(type.color.opacity(0.12))
                            .clipShape(Circle())

                        Text(step)
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            // CTA
            Button {
                activeCollectionPrompt = nil
            } label: {
                Text(type.emptyCTA)
                    .font(AppTypography.sectionHeader)
            }
            .buttonStyle(PrimaryButtonStyle(color: type.color))
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.appBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Collection Type

enum CollectionType: String, Identifiable, CaseIterable {
    case bookmarks
    case byFamily
    case custom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .bookmarks: return "Bookmarks"
        case .byFamily:  return "By Family"
        case .custom:    return "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .bookmarks: return "Species you want to remember"
        case .byFamily:  return "Organized by taxonomy"
        case .custom:    return "Your own groupings"
        }
    }

    var icon: String {
        switch self {
        case .bookmarks: return "bookmark.fill"
        case .byFamily:  return "leaf.fill"
        case .custom:    return "folder.fill"
        }
    }

    var color: Color {
        return .orangePrimary
    }

    var emptyTitle: String {
        switch self {
        case .bookmarks: return "No Bookmarks Yet"
        case .byFamily:  return "No Family Groups Yet"
        case .custom:    return "No Custom Collections Yet"
        }
    }

    var emptyMessage: String {
        switch self {
        case .bookmarks:
            return "Save the species that interest you most. Bookmarks make it easy to revisit and study plants you encounter in the field."
        case .byFamily:
            return "As you observe plants, they'll automatically group here by botanical family — a beautiful way to see patterns in nature."
        case .custom:
            return "Create your own collections to organize plants however you like — by habitat, season, color, or any theme you choose."
        }
    }

    var emptySteps: [String] {
        switch self {
        case .bookmarks:
            return [
                "Browse species in the Learn tab",
                "Tap the bookmark icon on any plant",
                "Find all your bookmarks here"
            ]
        case .byFamily:
            return [
                "Log observations in Botanize",
                "Identify the species you find",
                "Family groups build automatically"
            ]
        case .custom:
            return [
                "Tap \"New Collection\" below",
                "Give it a name and theme",
                "Add plants from anywhere in the app"
            ]
        }
    }

    var emptyCTA: String {
        switch self {
        case .bookmarks: return "Explore Species"
        case .byFamily:  return "Start Observing"
        case .custom:    return "Got It"
        }
    }
}

#Preview {
    NavigationStack {
        JournalView()
            .environmentObject(StoreManager(preview: true))
            .modelContainer(for: [PlantObservation.self, UserSettings.self, JournalNote.self], inMemory: true)
    }
}
