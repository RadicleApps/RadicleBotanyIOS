import SwiftUI
import SwiftData

struct TermsListView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \BotanyTerm.term) private var terms: [BotanyTerm]

    @State private var searchText = ""
    @State private var selectedGroup: String? = nil
    @State private var selectedSubcategory: String? = nil

    // MARK: - Parent Group Definitions

    private static let groupDefinitions: [(name: String, keywords: [String], color: Color)] = [
        ("Leaf",    ["leaf", "leaves", "leaf-like", "stipule", "stipellae"],     .greenSecondary),
        ("Flower",  ["flower", "floral", "petal", "sepal", "anther", "stamen",
                     "staminode", "carpel", "ovary", "style", "corolla",
                     "perianth", "inflorescence", "bract", "bracteole", "spathe"], .orangePrimary),
        ("Stem",    ["stem", "growth"],                                          .orangeLight),
        ("Fruit",   ["fruit", "seed", "cone"],                                   .warningAmber),
        ("Root",    ["root"],                                                    .greenLight),
        ("Surface", ["surface", "texture"],                                      .purpleLight),
        ("Other",   [],                                                          .purpleSecondary)
    ]

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    // MARK: - Computed Properties

    private var hasFullAccess: Bool {
        storeManager.isFeatureUnlocked(.fullTermAccess)
    }

    private func parentGroup(for category: String) -> String {
        let lower = category.lowercased()
        for group in Self.groupDefinitions where group.name != "Other" {
            for keyword in group.keywords {
                if lower.contains(keyword) { return group.name }
            }
        }
        return "Other"
    }

    private func groupDef(for name: String) -> (name: String, keywords: [String], color: Color) {
        Self.groupDefinitions.first { $0.name == name } ?? Self.groupDefinitions.last!
    }

    private func groupColor(for category: String) -> Color {
        groupDef(for: parentGroup(for: category)).color
    }

    private var activeGroupColor: Color {
        if let group = selectedGroup {
            return groupDef(for: group).color
        }
        return .purpleSecondary
    }

    private var availableGroups: [String] {
        let presentGroups = Set(terms.map { parentGroup(for: $0.category) })
        return Self.groupDefinitions.map(\.name).filter { presentGroups.contains($0) }
    }

    /// Subcategories available for the currently selected group, sorted alphabetically.
    private var availableSubcategories: [String] {
        guard let group = selectedGroup else { return [] }
        let termsInGroup: [BotanyTerm] = terms.filter { parentGroup(for: $0.category) == group }
        let cats = Set(termsInGroup.map { $0.category })
        return cats.sorted()
    }

    /// All filtered terms — applying group, subcategory, and search filters.
    private var filteredTerms: [BotanyTerm] {
        var result = terms

        if let group = selectedGroup {
            result = result.filter { parentGroup(for: $0.category) == group }
        }

        if let sub = selectedSubcategory {
            result = result.filter { $0.category == sub }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.term.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    /// Filtered terms that have an illustration, grouped by subcategory.
    private var illustratedBySubcategory: [TermSubcategory] {
        let illustrated: [BotanyTerm] = filteredTerms.filter {
            $0.imageURL != nil && !($0.imageURL?.isEmpty ?? true)
        }
        guard !illustrated.isEmpty else { return [] }

        let byCategory: [String: [BotanyTerm]] = Dictionary(grouping: illustrated) { $0.category }
        return byCategory
            .map { TermSubcategory(name: $0.key, terms: $0.value.sorted { $0.term < $1.term }) }
            .sorted { $0.name < $1.name }
    }

    /// Total illustrated count.
    private var illustratedCount: Int {
        illustratedBySubcategory.reduce(0) { $0 + $1.terms.count }
    }

    /// Filtered terms without images, grouped by parent group → subcategory.
    private var textOnlyGroups: [TermParentGroup] {
        let textOnly: [BotanyTerm] = filteredTerms.filter {
            $0.imageURL == nil || ($0.imageURL?.isEmpty ?? true)
        }
        return buildHierarchy(from: textOnly)
    }

    private func buildHierarchy(from termList: [BotanyTerm]) -> [TermParentGroup] {
        let byParent: [String: [BotanyTerm]] = Dictionary(grouping: termList) { parentGroup(for: $0.category) }
        let orderedNames: [String] = Self.groupDefinitions.map(\.name)

        let groups: [TermParentGroup] = orderedNames.compactMap { groupName -> TermParentGroup? in
            guard let termsInGroup = byParent[groupName], !termsInGroup.isEmpty else { return nil }

            let byCategory: [String: [BotanyTerm]] = Dictionary(grouping: termsInGroup) { $0.category }
            let subcategories: [TermSubcategory] = byCategory
                .map { TermSubcategory(name: $0.key, terms: $0.value.sorted { $0.term < $1.term }) }
                .sorted { $0.name < $1.name }

            let def = groupDef(for: groupName)
            return TermParentGroup(
                name: groupName,
                color: def.color,
                subcategories: subcategories,
                totalCount: termsInGroup.count
            )
        }
        return groups
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            groupFilterBar

            // Subcategory chips appear when a group is selected
            if selectedGroup != nil && availableSubcategories.count > 1 {
                subcategoryFilterBar
            }

            if filteredTerms.isEmpty {
                emptyState
            } else {
                resultCountBar

                ScrollView {
                    VStack(spacing: 0) {
                        if !illustratedBySubcategory.isEmpty {
                            illustratedGridSection
                        }

                        if !textOnlyGroups.isEmpty {
                            textListSection
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.terms)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(AppColors.textMuted)

            TextField("Search terms...", text: $searchText)
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

    // MARK: - Group Filter Bar (Row 1)

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(name: "All", color: .purpleSecondary, isSelected: selectedGroup == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGroup = nil
                        selectedSubcategory = nil
                    }
                }

                ForEach(availableGroups, id: \.self) { group in
                    let def = groupDef(for: group)
                    filterChip(name: group, color: def.color, isSelected: selectedGroup == group) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedGroup = group
                            selectedSubcategory = nil
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Subcategory Filter Bar (Row 2 — contextual)

    private var subcategoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                subFilterChip(name: "All \(selectedGroup ?? "")", isSelected: selectedSubcategory == nil) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedSubcategory = nil
                    }
                }

                ForEach(availableSubcategories, id: \.self) { sub in
                    subFilterChip(name: sub, isSelected: selectedSubcategory == sub) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSubcategory = sub
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Chip Components

    private func filterChip(name: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let bgColor: Color = isSelected ? color : AppColors.cardElevated
        let fgColor: Color = isSelected ? .white : AppColors.textSecondary
        let borderColor: Color = isSelected ? color : AppColors.border

        return Button(action: action) {
            Text(name)
                .font(AppTypography.tagText)
                .foregroundStyle(fgColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func subFilterChip(name: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let color: Color = activeGroupColor
        let bgColor: Color = isSelected ? color.opacity(0.2) : Color.clear
        let fgColor: Color = isSelected ? color : AppColors.textMuted
        let borderColor: Color = isSelected ? color.opacity(0.5) : AppColors.border.opacity(0.6)

        return Button(action: action) {
            Text(name)
                .font(AppTypography.caption)
                .foregroundStyle(fgColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result Count Bar

    private var resultCountBar: some View {
        HStack(spacing: 4) {
            let count = filteredTerms.count
            Text("\(count) term\(count == 1 ? "" : "s")")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)

            if illustratedCount > 0 {
                Text("· \(illustratedCount) illustrated")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            if selectedGroup != nil || selectedSubcategory != nil || !searchText.isEmpty {
                Text("·")
                    .foregroundStyle(AppColors.textMuted)
                Button {
                    selectedGroup = nil
                    selectedSubcategory = nil
                    searchText = ""
                } label: {
                    Text("Clear")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.brandPurple)
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

            Text("No terms found")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)

            if !searchText.isEmpty || selectedGroup != nil || selectedSubcategory != nil {
                Button {
                    searchText = ""
                    selectedGroup = nil
                    selectedSubcategory = nil
                } label: {
                    Text("Clear filters")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.brandPurple)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Illustrated Grid Section (grouped by subcategory)

    private var illustratedGridSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Text("Illustrated")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(illustratedCount)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.brandPurple.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.brandPurple.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Grid grouped by subcategory
            ForEach(illustratedBySubcategory, id: \.name) { subcategory in
                // Subcategory label
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(groupColor(for: subcategory.name).opacity(0.5))
                        .frame(width: 3, height: 12)

                    Text(subcategory.name)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Text("(\(subcategory.terms.count))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)

                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(subcategory.terms) { term in
                        illustratedTermCell(term)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func illustratedTermCell(_ term: BotanyTerm) -> some View {
        NavigationLink(destination: TermDetailView(term: term)) {
            illustratedCellBody(term, isLocked: false)
        }
        .buttonStyle(.plain)
    }

    private func illustratedCellBody(_ term: BotanyTerm, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                illustratedCellImage(term)
                if isLocked {
                    LockOverlay()
                }
            }

            Text(term.term)
                .font(AppTypography.tagText)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(term.category)
                .font(AppTypography.caption)
                .foregroundStyle(groupColor(for: term.category))
                .lineLimit(1)
        }
        .padding(.bottom, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func illustratedCellImage(_ term: BotanyTerm) -> some View {
        if let urlString = term.imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .clipped()
                case .failure:
                    cellImagePlaceholder
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                @unknown default:
                    cellImagePlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        } else {
            cellImagePlaceholder
        }
    }

    private var cellImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: AppRadius.button)
            .fill(AppColors.cardElevated)
            .frame(height: 100)
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(AppColors.textMuted.opacity(0.3))
            }
    }

    // MARK: - Text-Only List Section (grouped by parent → subcategory)

    private var textListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("All Terms")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            ForEach(textOnlyGroups, id: \.name) { group in
                parentGroupHeader(group)

                ForEach(group.subcategories, id: \.name) { subcategory in
                    subcategoryHeader(subcategory, color: group.color)

                    ForEach(subcategory.terms) { term in
                        termRow(term)
                    }
                }
            }
        }
    }

    // MARK: - Parent Group Header

    private func parentGroupHeader(_ group: TermParentGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.name)
                .font(AppTypography.buttonText)
                .foregroundStyle(group.color)

            Text("\(group.totalCount)")
                .font(AppTypography.caption)
                .foregroundStyle(group.color.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(group.color.opacity(0.1))
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Subcategory Header

    private func subcategoryHeader(_ subcategory: TermSubcategory, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.4))
                .frame(width: 3, height: 14)

            Text(subcategory.name)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textSecondary)

            Text("(\(subcategory.terms.count))")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppColors.cardElevated.opacity(0.3))
    }

    // MARK: - Term Row

    @ViewBuilder
    private func termRow(_ term: BotanyTerm) -> some View {
        NavigationLink(destination: TermDetailView(term: term)) {
            termRowContent(term)
        }
        .buttonStyle(.plain)
    }

    private func termRowContent(_ term: BotanyTerm, showLock: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(term.term)
                    .font(AppTypography.bodyText)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)

                if !term.descriptionShort.isEmpty {
                    Text(term.descriptionShort)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            if showLock {
                Image(systemName: "lock.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textMuted)
            } else {
                Image(systemName: "chevron.right")
                    .font(AppTypography.inter(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .contentShape(Rectangle())
        .overlay(
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Data Models

private struct TermParentGroup {
    let name: String
    let color: Color
    let subcategories: [TermSubcategory]
    let totalCount: Int
}

private struct TermSubcategory {
    let name: String
    let terms: [BotanyTerm]
}

#Preview {
    NavigationStack {
        TermsListView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: BotanyTerm.self, inMemory: true)
    .preferredColorScheme(.dark)
}
