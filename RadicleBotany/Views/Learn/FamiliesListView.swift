import SwiftUI
import SwiftData

struct FamiliesListView: View {
    @Query(sort: \Family.familyLatin) private var families: [Family]
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]

    @State private var searchText = ""
    @State private var selectedOrder: String? = nil

    // MARK: - Cached Data (computed once, updated on change)

    @State private var cachedOrders: [String] = []
    @State private var cachedFilteredFamilies: [Family] = []
    @State private var cachedGroupedFamilies: [(letter: String, families: [Family])] = []
    @State private var cachedSpeciesCounts: [String: Int] = [:]

    private func recomputeAll() {
        cachedOrders = Set(families.compactMap { $0.order }.filter { !$0.isEmpty }).sorted()
        // Pre-compute species count per family — avoids O(families × plants) per render
        var counts: [String: Int] = [:]
        for plant in allPlants {
            counts[plant.familyLatin, default: 0] += 1
        }
        cachedSpeciesCounts = counts
        recomputeFiltered()
    }

    private func recomputeFiltered() {
        var result = Array(families)

        if let order = selectedOrder {
            result = result.filter { $0.order == order }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.familyLatin.localizedCaseInsensitiveContains(searchText) ||
                $0.familyEnglish.localizedCaseInsensitiveContains(searchText) ||
                $0.order.localizedCaseInsensitiveContains(searchText) ||
                $0.genera.localizedCaseInsensitiveContains(searchText)
            }
        }

        cachedFilteredFamilies = result

        let grouped = Dictionary(grouping: result) { family -> String in
            let firstChar = family.familyLatin.prefix(1).uppercased()
            return firstChar.isEmpty ? "#" : firstChar
        }
        cachedGroupedFamilies = grouped
            .map { (letter: $0.key, families: $0.value) }
            .sorted { $0.letter < $1.letter }
    }

    private var hasActiveFilters: Bool {
        selectedOrder != nil || !searchText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            FilterChipBar(
                categories: cachedOrders,
                selectedCategory: $selectedOrder,
                accentColor: .orangePrimary
            )

            resultCountBar

            if cachedFilteredFamilies.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(cachedGroupedFamilies, id: \.letter) { group in
                        Section {
                            ForEach(group.families) { family in
                                familyRow(family)
                            }
                        } header: {
                            Text(group.letter)
                                .font(AppTypography.sectionHeader)
                                .foregroundStyle(AppColors.primaryAmber)
                        }
                    }

                    // Bottom padding for tab bar
                    Color.clear.frame(height: 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.families)
        .onAppear { if cachedOrders.isEmpty && !families.isEmpty { recomputeAll() } }
        .onChange(of: families.count) { _, _ in recomputeAll() }
        .onChange(of: allPlants.count) { _, _ in recomputeAll() }
        .onChange(of: searchText) { _, _ in recomputeFiltered() }
        .onChange(of: selectedOrder) { _, _ in recomputeFiltered() }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.textMuted)

            TextField("Search families, orders, genera...", text: $searchText)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.inter(size: 14))
                        .foregroundStyle(AppColors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Result Count Bar

    private var resultCountBar: some View {
        HStack(spacing: 4) {
            let count = cachedFilteredFamilies.count
            let total = families.count

            Text("\(count) of \(total) families")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)

            if let order = selectedOrder {
                Text("in \(order)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.primaryAmber)
            }

            if hasActiveFilters {
                Text("·")
                    .foregroundStyle(AppColors.textMuted)
                Button {
                    selectedOrder = nil
                    searchText = ""
                } label: {
                    Text("Clear")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.primaryAmber)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("Zygomorphic (symmetry) color")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .opacity(0.5)

            Text("No families found")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)

            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            if hasActiveFilters {
                Button {
                    searchText = ""
                    selectedOrder = nil
                } label: {
                    Text("Clear all filters")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.primaryAmber)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primaryAmber.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Family Row

    private func familyRow(_ family: Family) -> some View {
        let index = cachedFilteredFamilies.firstIndex(where: { $0.id == family.id }) ?? 0
        return NavigationLink(destination: CollectionPagerView(items: cachedFilteredFamilies, startIndex: index) { f in
            FamilyDetailView(family: f)
        }) {
            familyRowContent(family)
        }
        .listRowBackground(AppColors.cardBackground)
        .listRowSeparatorTint(AppColors.border)
    }

    private func familyRowContent(_ family: Family, showLock: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.circle.fill")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.primaryAmber)
                .frame(width: 32, height: 32)
                .background(AppColors.primaryAmber.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

            VStack(alignment: .leading, spacing: 3) {
                Text(family.familyLatin)
                    .font(AppTypography.bodyText)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 6) {
                    Text(family.familyEnglish)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)

                    if !family.order.isEmpty {
                        Text("·")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                        Text(family.order)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.primaryAmber.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            let speciesCount = cachedSpeciesCounts[family.familyLatin] ?? 0
            if speciesCount > 0 {
                VStack(spacing: 1) {
                    Text("\(speciesCount)")
                        .font(AppTypography.tagText)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.success)
                    Text("species")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.textMuted)
                }
            }

            if showLock {
                Image(systemName: "lock.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        FamiliesListView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Family.self, Plant.self], inMemory: true)
    .preferredColorScheme(.dark)
}
