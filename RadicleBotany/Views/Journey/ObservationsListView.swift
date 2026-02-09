import SwiftUI
import SwiftData

struct ObservationsListView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var allObservations: [PlantObservation] = []

    @State private var sortOption: SortOption = .date
    @State private var filterOption: FilterOption = .all

    enum SortOption: String, CaseIterable, Identifiable {
        case date = "Date"
        case species = "Species"
        case location = "Location"

        var id: String { rawValue }
    }

    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case hasSpecies = "Has Species"
        case noSpecies = "No Species"

        var id: String { rawValue }
    }

    private var filteredObservations: [PlantObservation] {
        let filtered: [PlantObservation]
        switch filterOption {
        case .all:
            filtered = allObservations
        case .hasSpecies:
            filtered = allObservations.filter { $0.plantScientificName != nil && !($0.plantScientificName?.isEmpty ?? true) }
        case .noSpecies:
            filtered = allObservations.filter { $0.plantScientificName == nil || ($0.plantScientificName?.isEmpty ?? true) }
        }

        switch sortOption {
        case .date:
            return filtered.sorted { $0.date > $1.date }
        case .species:
            return filtered.sorted {
                ($0.plantScientificName ?? "zzz") < ($1.plantScientificName ?? "zzz")
            }
        case .location:
            return filtered.sorted {
                let hasLoc0 = ($0.latitude != nil && $0.longitude != nil)
                let hasLoc1 = ($1.latitude != nil && $1.longitude != nil)
                if hasLoc0 == hasLoc1 { return $0.date > $1.date }
                return hasLoc0 && !hasLoc1
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            observationsList
        }
        .background(Color.appBackground)
        .navigationTitle("Observations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                    Text(sortOption.rawValue)
                        .font(AppFont.caption())
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.surfaceElevated)
                .clipShape(Capsule())
            }

            Menu {
                Picker("Filter", selection: $filterOption) {
                    ForEach(FilterOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 11))
                    Text(filterOption.rawValue)
                        .font(AppFont.caption())
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.surfaceElevated)
                .clipShape(Capsule())
            }

            Spacer()

            Text("\(filteredObservations.count) result\(filteredObservations.count == 1 ? "" : "s")")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Observations List

    private var observationsList: some View {
        Group {
            if filteredObservations.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredObservations) { observation in
                            NavigationLink {
                                ObservationDetailView(observation: observation)
                            } label: {
                                observationRow(observation)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Observation Row

    private func observationRow(_ observation: PlantObservation) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let photoData = observation.photoData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    Color.surfaceElevated
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.textMuted)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(observation.plantScientificName ?? "Unidentified")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .italic(observation.plantScientificName != nil)

                Text(observation.date.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)

                if let lat = observation.latitude, let lon = observation.longitude {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9))
                        Text(String(format: "%.3f, %.3f", lat, lon))
                            .font(AppFont.caption(10))
                    }
                    .foregroundStyle(Color.textMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.textMuted)
        }
        .cardStyle(padding: 12)
    }

    // MARK: - Empty State

    private func loadData() {
        allObservations = (try? modelContext.fetch(FetchDescriptor<PlantObservation>(sortBy: [SortDescriptor(\PlantObservation.date, order: .reverse)]))) ?? []
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "binoculars")
                .font(.system(size: 40))
                .foregroundStyle(Color.textMuted)

            Text("No observations found")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textSecondary)

            if filterOption != .all {
                Text("Try adjusting your filters.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            } else {
                Text("Start by capturing a plant in the Botanize tab.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        ObservationsListView()
            .modelContainer(for: PlantObservation.self, inMemory: true)
    }
}
