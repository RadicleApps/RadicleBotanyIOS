import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager

    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]
    @Query(sort: \Family.familyLatin) private var allFamilies: [Family]
    @Query(sort: \BotanyTerm.term) private var allTerms: [BotanyTerm]

    @State private var searchText = ""
    @State private var scope: SearchScope = .all
    @FocusState private var isSearchFocused: Bool

    enum SearchScope: String, CaseIterable {
        case all = "All"
        case plants = "Plants"
        case families = "Families"
        case terms = "Terms"

        var icon: String {
            switch self {
            case .all: return "magnifyingglass"
            case .plants: return "leaf.fill"
            case .families: return "leaf.circle.fill"
            case .terms: return "text.book.closed.fill"
            }
        }

        var color: Color {
            switch self {
            case .all: return .orangePrimary
            case .plants: return .greenSecondary
            case .families: return .purpleSecondary
            case .terms: return .orangePrimary
            }
        }
    }

    // MARK: - Filtered Results

    private var filteredPlants: [Plant] {
        guard !searchText.isEmpty else { return [] }
        return allPlants.filter { plant in
            plant.scientificName.localizedCaseInsensitiveContains(searchText) ||
            plant.commonName.localizedCaseInsensitiveContains(searchText) ||
            plant.genus.localizedCaseInsensitiveContains(searchText) ||
            plant.familyLatin.localizedCaseInsensitiveContains(searchText) ||
            (plant.alternativeCommonNames?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var filteredFamilies: [Family] {
        guard !searchText.isEmpty else { return [] }
        return allFamilies.filter { family in
            family.familyLatin.localizedCaseInsensitiveContains(searchText) ||
            family.familyEnglish.localizedCaseInsensitiveContains(searchText) ||
            family.order.localizedCaseInsensitiveContains(searchText) ||
            family.genera.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredTerms: [BotanyTerm] {
        guard !searchText.isEmpty else { return [] }
        return allTerms.filter { term in
            term.term.localizedCaseInsensitiveContains(searchText) ||
            term.category.localizedCaseInsensitiveContains(searchText) ||
            term.descriptionShort.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var hasResults: Bool {
        switch scope {
        case .all:
            return !filteredPlants.isEmpty || !filteredFamilies.isEmpty || !filteredTerms.isEmpty
        case .plants:
            return !filteredPlants.isEmpty
        case .families:
            return !filteredFamilies.isEmpty
        case .terms:
            return !filteredTerms.isEmpty
        }
    }

    private var totalResultCount: Int {
        filteredPlants.count + filteredFamilies.count + filteredTerms.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom search bar
            searchBar

            // Scope tabs
            scopeTabs

            // Content
            if searchText.isEmpty {
                emptyState
            } else if !hasResults {
                noResultsState
            } else {
                resultsList
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                InfoButton(guide: .search, style: .toolbar)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.primaryAmber)
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Custom Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 15))
                .foregroundStyle(AppColors.textMuted)

            TextField("Search plants, families, terms...", text: $searchText)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
                .autocorrectionDisabled()
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.inter(size: 15))
                        .foregroundStyle(AppColors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppColors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Scope Tabs

    private var scopeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases, id: \.self) { tab in
                    scopeTab(tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func scopeTab(_ tab: SearchScope) -> some View {
        let isSelected = scope == tab
        let count: Int = {
            switch tab {
            case .all: return totalResultCount
            case .plants: return filteredPlants.count
            case .families: return filteredFamilies.count
            case .terms: return filteredTerms.count
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                scope = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(AppTypography.inter(size: 11))

                Text(tab.rawValue)
                    .font(AppTypography.tagText)

                if !searchText.isEmpty && count > 0 {
                    Text("\(count)")
                        .font(AppTypography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            isSelected ? Color.white.opacity(0.25) : tab.color.opacity(0.15)
                        )
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? tab.color : AppColors.cardElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? tab.color : AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            if (scope == .all || scope == .plants), !filteredPlants.isEmpty {
                plantsSection
            }
            if (scope == .all || scope == .families), !filteredFamilies.isEmpty {
                familiesSection
            }
            if (scope == .all || scope == .terms), !filteredTerms.isEmpty {
                termsSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Plants Section

    private var plantsSection: some View {
        Section {
            ForEach(filteredPlants, id: \.scientificName) { plant in
                NavigationLink {
                    PlantDetailView(plant: plant)
                } label: {
                    plantRow(plant)
                }
                .listRowBackground(AppColors.cardBackground)
            }
        } header: {
            sectionHeader("Plants", count: filteredPlants.count, color: .greenSecondary)
        }
    }

    private func plantRow(_ plant: Plant) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.success)
                .frame(width: 28, height: 28)
                .background(AppColors.success.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(plant.scientificName)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)
                    .italic()

                HStack(spacing: 6) {
                    Text(plant.commonName)
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textSecondary)

                    if !plant.genus.isEmpty {
                        Text("·")
                            .font(AppTypography.inter(size: 8))
                            .foregroundStyle(AppColors.textMuted.opacity(0.5))
                        Text(plant.genus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                            .italic()
                    }
                }
            }

            Spacer()

            if !plant.isFree && !storeManager.isFeatureUnlocked(.fullSpeciesAccess) {
                Image(systemName: "lock.fill")
                    .font(AppTypography.inter(size: 12))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Families Section

    private var familiesSection: some View {
        Section {
            ForEach(filteredFamilies, id: \.familyLatin) { family in
                NavigationLink {
                    FamilyDetailView(family: family)
                } label: {
                    familyRow(family)
                }
                .listRowBackground(AppColors.cardBackground)
            }
        } header: {
            sectionHeader("Families", count: filteredFamilies.count, color: .purpleSecondary)
        }
    }

    private func familyRow(_ family: Family) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.circle.fill")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.brandPurple)
                .frame(width: 28, height: 28)
                .background(AppColors.brandPurple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(family.familyLatin)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 6) {
                    Text(family.familyEnglish)
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textSecondary)

                    if !family.order.isEmpty {
                        Text("·")
                            .font(AppTypography.inter(size: 8))
                            .foregroundStyle(AppColors.textMuted.opacity(0.5))
                        Text(family.order)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                }
            }

            Spacer()

            if !family.isFree && !storeManager.isFeatureUnlocked(.fullFamilyAccess) {
                Image(systemName: "lock.fill")
                    .font(AppTypography.inter(size: 12))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Terms Section

    private var termsSection: some View {
        Section {
            ForEach(filteredTerms, id: \.term) { term in
                NavigationLink {
                    TermDetailView(term: term)
                } label: {
                    termRow(term)
                }
                .listRowBackground(AppColors.cardBackground)
            }
        } header: {
            sectionHeader("Terms", count: filteredTerms.count, color: .orangePrimary)
        }
    }

    private func termRow(_ term: BotanyTerm) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "text.book.closed.fill")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.primaryAmber)
                .frame(width: 28, height: 28)
                .background(AppColors.primaryAmber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(term.term)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 6) {
                    Text(term.category)
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textSecondary)

                    if !term.descriptionShort.isEmpty {
                        Text("·")
                            .font(AppTypography.inter(size: 8))
                            .foregroundStyle(AppColors.textMuted.opacity(0.5))
                        Text(term.descriptionShort)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if !term.isFree && !storeManager.isFeatureUnlocked(.fullTermAccess) {
                Image(systemName: "lock.fill")
                    .font(AppTypography.inter(size: 12))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Text("\(count)")
                .font(AppTypography.caption)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 4)
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image("Solitary flower color")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .opacity(0.5)

                Text("Search across all content")
                    .font(AppTypography.displayMedium)
                    .foregroundStyle(AppColors.textSecondary)

                Text("Find plants, families, and botanical terms")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()
        }
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image("Solitary flower color")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .opacity(0.3)

                Text("No matches found")
                    .font(AppTypography.displayMedium)
                    .foregroundStyle(AppColors.textSecondary)

                Text("Try a different search term or scope")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()
        }
    }
}

// Detail views are defined in Views/Detail/
// PlantDetailView, FamilyDetailView, TermDetailView

#Preview {
    NavigationStack {
        SearchView()
            .environmentObject(StoreManager(preview: true))
            .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self])
    }
}
