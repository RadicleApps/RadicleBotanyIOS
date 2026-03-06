import SwiftUI
import SwiftData

struct EntityLinkPicker: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]
    @Query(sort: \Family.familyLatin) private var allFamilies: [Family]
    @Query(sort: \BotanyTerm.term) private var allTerms: [BotanyTerm]
    @Query(sort: \PlantObservation.date, order: .reverse) private var allObservations: [PlantObservation]

    @State private var searchText = ""
    @State private var scope: LinkScope = .plant
    @FocusState private var isSearchFocused: Bool

    var onSelect: (LinkedEntityType, String) -> Void

    enum LinkScope: String, CaseIterable {
        case plant = "Plant"
        case family = "Family"
        case term = "Term"
        case observation = "Observation"

        var color: Color {
            switch self {
            case .plant: return .greenSecondary
            case .family: return .purpleSecondary
            case .term: return .orangePrimary
            case .observation: return .orangeLight
            }
        }
    }

    // MARK: - Filtered Results

    private var filteredPlants: [Plant] {
        guard !searchText.isEmpty else { return Array(allPlants.prefix(20)) }
        return allPlants.filter { plant in
            plant.scientificName.localizedCaseInsensitiveContains(searchText) ||
            plant.commonName.localizedCaseInsensitiveContains(searchText) ||
            plant.genus.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredFamilies: [Family] {
        guard !searchText.isEmpty else { return Array(allFamilies.prefix(20)) }
        return allFamilies.filter { family in
            family.familyLatin.localizedCaseInsensitiveContains(searchText) ||
            family.familyEnglish.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredTerms: [BotanyTerm] {
        guard !searchText.isEmpty else { return Array(allTerms.prefix(20)) }
        return allTerms.filter { term in
            term.term.localizedCaseInsensitiveContains(searchText) ||
            term.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredObservations: [PlantObservation] {
        guard !searchText.isEmpty else { return Array(allObservations.prefix(20)) }
        return allObservations.filter { obs in
            if let name = obs.plantScientificName {
                return name.localizedCaseInsensitiveContains(searchText)
            }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(AppColors.textMuted.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header
            Text("Link to...")
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.bottom, 12)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(AppColors.textMuted)

                TextField("Search...", text: $searchText)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            }
            .padding(10)
            .background(AppColors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Scope tabs
            scopeTabs
                .padding(.bottom, 8)

            // Results
            ScrollView {
                LazyVStack(spacing: 2) {
                    switch scope {
                    case .plant:
                        ForEach(filteredPlants) { plant in
                            plantRow(plant)
                        }
                        if filteredPlants.isEmpty {
                            emptySearchState
                        }
                    case .family:
                        ForEach(filteredFamilies) { family in
                            familyRow(family)
                        }
                        if filteredFamilies.isEmpty {
                            emptySearchState
                        }
                    case .term:
                        ForEach(filteredTerms) { term in
                            termRow(term)
                        }
                        if filteredTerms.isEmpty {
                            emptySearchState
                        }
                    case .observation:
                        ForEach(filteredObservations) { obs in
                            observationRow(obs)
                        }
                        if filteredObservations.isEmpty {
                            emptySearchState
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(AppColors.appBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Scope Tabs

    private var scopeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LinkScope.allCases, id: \.rawValue) { tab in
                    let isSelected = scope == tab

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scope = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(AppTypography.caption)
                            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? tab.color : AppColors.cardElevated)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Row Builders

    private func plantRow(_ plant: Plant) -> some View {
        Button {
            onSelect(.plant, plant.scientificName)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(AppTypography.inter(size: 12))
                    .foregroundStyle(AppColors.success)
                    .frame(width: 32, height: 32)
                    .background(AppColors.success.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.scientificName)
                        .font(AppTypography.fieldLabel)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(plant.commonName)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(AppTypography.inter(size: 16))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private func familyRow(_ family: Family) -> some View {
        Button {
            onSelect(.family, family.familyLatin)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "leaf.circle.fill")
                    .font(AppTypography.inter(size: 12))
                    .foregroundStyle(AppColors.brandPurple)
                    .frame(width: 32, height: 32)
                    .background(AppColors.brandPurple.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                VStack(alignment: .leading, spacing: 2) {
                    Text(family.familyLatin)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(family.familyEnglish)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(AppTypography.inter(size: 16))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private func termRow(_ term: BotanyTerm) -> some View {
        Button {
            onSelect(.term, term.term)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "text.book.closed.fill")
                    .font(AppTypography.inter(size: 12))
                    .foregroundStyle(AppColors.primaryAmber)
                    .frame(width: 32, height: 32)
                    .background(AppColors.primaryAmber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                VStack(alignment: .leading, spacing: 2) {
                    Text(term.term)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(term.category)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(AppTypography.inter(size: 16))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private func observationRow(_ obs: PlantObservation) -> some View {
        let displayName = obs.plantScientificName ?? "Unidentified"
        let dateStr = obs.date.formatted(date: .abbreviated, time: .omitted)

        return Button {
            onSelect(.observation, displayName + " (\(dateStr))")
            dismiss()
        } label: {
            HStack(spacing: 12) {
                if let photoData = obs.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                } else {
                    Image(systemName: "camera.fill")
                        .font(AppTypography.inter(size: 12))
                        .foregroundStyle(AppColors.primaryHoney)
                        .frame(width: 32, height: 32)
                        .background(AppColors.primaryHoney.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)
                        .italic(obs.plantScientificName != nil)
                        .lineLimit(1)

                    Text(dateStr)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(AppTypography.inter(size: 16))
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 24))
                .foregroundStyle(AppColors.textMuted)

            Text("No results found")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    EntityLinkPicker { type, id in
        print("Selected: \(type) — \(id)")
    }
    .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self, PlantObservation.self], inMemory: true)
}
