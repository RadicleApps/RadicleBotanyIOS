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

    enum SearchScope: String, CaseIterable {
        case all = "All"
        case plants = "Plants"
        case families = "Families"
        case terms = "Terms"
    }

    // MARK: - Filtered Results

    private var filteredPlants: [Plant] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return allPlants.filter { plant in
            plant.scientificName.lowercased().contains(query) ||
            plant.commonName.lowercased().contains(query)
        }
    }

    private var filteredFamilies: [Family] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return allFamilies.filter { family in
            family.familyLatin.lowercased().contains(query) ||
            family.familyEnglish.lowercased().contains(query)
        }
    }

    private var filteredTerms: [BotanyTerm] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return allTerms.filter { term in
            term.term.lowercased().contains(query)
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

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            Group {
                if searchText.isEmpty {
                    emptyState
                } else if !hasResults {
                    noResultsState
                } else {
                    resultsList
                }
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search plants, families, terms...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.orangePrimary)
            }
        }
    }

    // MARK: - Scope Picker

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(spacing: 0) {
            scopePicker

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
                .listRowBackground(Color.surface)
            }
        } header: {
            sectionHeader("Plants", count: filteredPlants.count)
        }
    }

    private func plantRow(_ plant: Plant) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.greenSecondary)
                .frame(width: 28, height: 28)
                .background(Color.greenSecondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(plant.scientificName)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)
                    .italic()

                Text(plant.commonName)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if !plant.isFree && !storeManager.isFeatureUnlocked(.fullSpeciesAccess) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
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
                .listRowBackground(Color.surface)
            }
        } header: {
            sectionHeader("Families", count: filteredFamilies.count)
        }
    }

    private func familyRow(_ family: Family) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tree.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.purpleSecondary)
                .frame(width: 28, height: 28)
                .background(Color.purpleSecondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(family.familyLatin)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)

                Text(family.familyEnglish)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if !storeManager.isFeatureUnlocked(.fullFamilyAccess) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
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
                .listRowBackground(Color.surface)
            }
        } header: {
            sectionHeader("Terms", count: filteredTerms.count)
        }
    }

    private func termRow(_ term: BotanyTerm) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.orangePrimary)
                .frame(width: 28, height: 28)
                .background(Color.orangePrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(term.term)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textPrimary)

                Text(term.category)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if !term.isFree && !storeManager.isFeatureUnlocked(.fullTermAccess) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textSecondary)

            Spacer()

            Text("\(count)")
                .font(AppFont.caption())
                .foregroundStyle(Color.textMuted)
        }
        .padding(.horizontal, 4)
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            scopePicker

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.textMuted)

                Text("Search across all content")
                    .font(AppFont.bodyLarge())
                    .foregroundStyle(Color.textSecondary)

                Text("Find plants, families, and botanical terms")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

            Spacer()
        }
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: 0) {
            scopePicker

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.textMuted)

                Text("No matches found")
                    .font(AppFont.bodyLarge())
                    .foregroundStyle(Color.textSecondary)

                Text("Try a different search term or scope")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
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
            .environmentObject(StoreManager())
            .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self])
    }
}
