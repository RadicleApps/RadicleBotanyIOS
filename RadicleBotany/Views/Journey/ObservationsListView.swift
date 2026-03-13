import SwiftUI
import SwiftData

struct ObservationsListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlantObservation.date, order: .reverse)
    private var allObservations: [PlantObservation]

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
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
                        .font(AppTypography.inter(size: 11))
                    Text(sortOption.rawValue)
                        .font(AppTypography.tagText)
                }
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.cardElevated)
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
                        .font(AppTypography.inter(size: 11))
                    Text(filterOption.rawValue)
                        .font(AppTypography.tagText)
                }
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.cardElevated)
                .clipShape(Capsule())
            }

            Spacer()

            Text("\(filteredObservations.count) result\(filteredObservations.count == 1 ? "" : "s")")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
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
                    .padding(.bottom, 80)
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

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(observation.plantScientificName ?? "Unidentified")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .italic(observation.plantScientificName != nil)

                Text(observation.date.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)

                if let lat = observation.latitude, let lon = observation.longitude {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(AppTypography.inter(size: 9))
                        Text(String(format: "%.3f, %.3f", lat, lon))
                            .font(AppTypography.caption)
                    }
                    .foregroundStyle(AppColors.textMuted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.inter(size: 12))
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(12).cardStyle(elevated: false, interactive: true)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("Trillium")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
                .opacity(0.5)

            Text("No observations found")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)

            if filterOption != .all {
                Text("Try adjusting your filters.")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            } else {
                Text("Start by capturing a plant in the Botanize tab.")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
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
