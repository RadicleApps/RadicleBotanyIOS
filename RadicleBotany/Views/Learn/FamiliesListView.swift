import SwiftUI
import SwiftData

struct FamiliesListView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Family.familyLatin) private var families: [Family]
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]

    @State private var searchText = ""
    @State private var selectedOrder: String? = nil

    // MARK: - Computed Properties

    private var allOrders: [String] {
        let orders = Set(families.compactMap { $0.order }.filter { !$0.isEmpty })
        return orders.sorted()
    }

    private var filteredFamilies: [Family] {
        var result = families

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

        return result
    }

    private var groupedFamilies: [(letter: String, families: [Family])] {
        let grouped = Dictionary(grouping: filteredFamilies) { family -> String in
            let firstChar = family.familyLatin.prefix(1).uppercased()
            return firstChar.isEmpty ? "#" : firstChar
        }

        return grouped
            .map { (letter: $0.key, families: $0.value) }
            .sorted { $0.letter < $1.letter }
    }

    private var isUnlocked: Bool {
        storeManager.isFeatureUnlocked(.fullFamilyAccess)
    }

    private var hasActiveFilters: Bool {
        selectedOrder != nil || !searchText.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            FilterChipBar(
                categories: allOrders,
                selectedCategory: $selectedOrder,
                accentColor: .orangePrimary
            )

            resultCountBar

            if filteredFamilies.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedFamilies, id: \.letter) { group in
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Families")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.families)
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
            let count = filteredFamilies.count
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
        NavigationLink(destination: FamilyDetailView(family: family)) {
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

            let speciesCount = allPlants.filter { $0.familyLatin == family.familyLatin }.count
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
