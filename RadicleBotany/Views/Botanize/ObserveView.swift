import SwiftUI
import SwiftData

// MARK: - Plant Match Result

struct PlantMatchResult: Identifiable {
    let id = UUID()
    let plant: Plant
    let matchPercentage: Double
    let matchedTraits: Int
    let totalTraits: Int
}

// MARK: - ObserveView

struct ObserveView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @Query private var plants: [Plant]
    @Query(filter: #Predicate<BotanyTerm> { $0.showPlantID == true })
    private var botanyTerms: [BotanyTerm]

    // MARK: - State

    // Bindings for parent-managed toolbar Matches pill
    @Binding var showResults: Bool
    var onMatchStateChanged: ((Int, Bool) -> Void)? = nil

    @State private var selectedOrgan: PlantOrgan = .leaf
    @State private var selectedSubcategory: String? = nil
    @State private var selectedTraits: [String: Set<String>] = [:]
    @State private var matchResults: [PlantMatchResult] = []
    @State private var longPressedTerm: BotanyTerm? = nil

    @AppStorage("observeQuestionsToday") private var observeQuestionsToday: Int = 0
    @AppStorage("observeQuestionsDate") private var observeQuestionsDate: String = ""
    @AppStorage("hasSeenObserveCoach") private var hasSeenObserveCoach = false
    @State private var coachStep = 0
    @State private var showCoach = false

    private let freeQuestionLimit = 3

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    // MARK: - Body

    private var totalSelectionCount: Int {
        selectedTraits.values.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Coach tip banner (first-time only)
            if showCoach {
                observeCoachBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Layer 1: Organ selector
            organSelector
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            // Layer 2: Subcategory filter chips
            subcategoryFilterBar
                .padding(.bottom, 4)

            // Selection summary bar (shows active selections)
            if !selectedTraits.isEmpty {
                selectionSummaryBar
            }

            Divider()
                .overlay(AppColors.border)

            // Browsable collection
            ScrollView {
                VStack(spacing: 0) {
                    if filteredSubcategoryGroups.isEmpty {
                        emptyStateCard
                            .padding(16)
                    } else {
                        traitCollectionGrid
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 100)
                    }
                }
            }
        }
        .background(AppColors.appBackground)
        .animation(.easeInOut(duration: 0.25), value: selectedOrgan)
        .animation(.easeInOut(duration: 0.2), value: selectedSubcategory)
        .sheet(isPresented: $showResults) {
            resultsModal
        }
        .sheet(item: $longPressedTerm) { term in
            NavigationStack {
                TermDetailView(term: term)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                longPressedTerm = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(AppTypography.inter(size: 20))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedOrgan) { _, _ in
            selectedSubcategory = nil
        }
        .onChange(of: selectedTraits) { _, _ in
            matchResults = computeMatchingPlants()
            onMatchStateChanged?(matchResults.count, !selectedTraits.isEmpty)
        }
        .onAppear {
            if !hasSeenObserveCoach {
                withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                    showCoach = true
                }
            }
        }
    }

    // MARK: - Current Questions / Subcategories

    private var currentQuestions: [TraitQuestion] {
        selectedOrgan.traitQuestions
    }

    /// Unique subcategory titles for the current organ, in definition order.
    private var subcategoryTitles: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for q in currentQuestions {
            if !seen.contains(q.title) {
                seen.insert(q.title)
                result.append(q.title)
            }
        }
        return result
    }

    /// Groups of terms for the current organ, filtered by subcategory if one is selected.
    /// Shows all terms marked showPlantID=true; traitTermImage handles missing images with a placeholder.
    private var filteredSubcategoryGroups: [TraitTermGroup] {
        let questions: [TraitQuestion]
        if let sub = selectedSubcategory {
            questions = currentQuestions.filter { $0.title == sub }
        } else {
            questions = currentQuestions
        }

        var groups: [TraitTermGroup] = []
        for question in questions {
            let allTerms = termsForCategory(question.category)
            if !allTerms.isEmpty {
                let sorted = allTerms.sorted { $0.term < $1.term }
                groups.append(TraitTermGroup(question: question, terms: sorted))
            }
        }
        return groups
    }

    // MARK: - Organ Selector (Layer 1)

    /// Organs that have at least one trait question (hides empty ones like Bark)
    private var visibleOrgans: [PlantOrgan] {
        PlantOrgan.allCases.filter { !$0.traitQuestions.isEmpty }
    }

    private var organSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(visibleOrgans) { organ in
                    organPill(organ)
                }
            }
        }
    }

    private func organPill(_ organ: PlantOrgan) -> some View {
        let isSelected: Bool = selectedOrgan == organ

        return Button {
            withAnimation { selectedOrgan = organ }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: organ.icon)
                    .font(AppTypography.inter(size: 16))
                Text(organ.rawValue)
                    .font(AppTypography.caption)
            }
            .foregroundStyle(isSelected ? AppColors.primaryAmber : AppColors.textMuted)
            .frame(width: 62)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.primaryAmber.opacity(0.12) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(isSelected ? AppColors.primaryAmber.opacity(0.4) : AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subcategory Filter Chips (Layer 2)

    private var subcategoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                subcategoryChip(
                    name: "All \(selectedOrgan.rawValue)",
                    isSelected: selectedSubcategory == nil
                ) {
                    withAnimation { selectedSubcategory = nil }
                }

                ForEach(subcategoryTitles, id: \.self) { title in
                    let selCount: Int = {
                        guard let q = currentQuestions.first(where: { $0.title == title }) else { return 0 }
                        return selectedTraits[q.category]?.count ?? 0
                    }()

                    subcategoryChip(
                        name: title,
                        isSelected: selectedSubcategory == title,
                        selectionCount: selCount
                    ) {
                        withAnimation {
                            selectedSubcategory = selectedSubcategory == title ? nil : title
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func subcategoryChip(
        name: String,
        isSelected: Bool,
        selectionCount: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        let hasSelection: Bool = selectionCount > 0
        let bgColor: Color = isSelected ? AppColors.primaryAmber.opacity(0.15) : (hasSelection ? AppColors.primaryAmber.opacity(0.08) : Color.clear)
        let fgColor: Color = isSelected ? AppColors.primaryAmber : (hasSelection ? AppColors.primaryAmber : AppColors.textMuted)
        let borderColor: Color = isSelected ? AppColors.primaryAmber.opacity(0.5) : (hasSelection ? AppColors.primaryAmber.opacity(0.3) : AppColors.border.opacity(0.6))

        return Button(action: action) {
            HStack(spacing: 4) {
                if hasSelection && !isSelected {
                    Text("\(selectionCount)")
                        .font(AppTypography.tagText)
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(AppColors.primaryAmber)
                        .clipShape(Circle())
                }
                Text(name)
                    .font(AppTypography.tagText)
            }
            .foregroundStyle(fgColor)
            .padding(.horizontal, 12)
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

    // MARK: - Selection Summary Bar

    private var selectionSummaryBar: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Selected traits as removable pills — one per individual value
                    ForEach(Array(selectedTraits.keys.sorted()), id: \.self) { category in
                        if let values = selectedTraits[category] {
                            ForEach(Array(values.sorted()), id: \.self) { value in
                                selectedTraitPill(category: category, value: value)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    // Results button
                    Button {
                        showResults = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(matchResults.count) matches")
                                .font(AppTypography.tagText)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.inter(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppColors.primaryAmber)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Clear all
                    Button {
                        withAnimation { selectedTraits.removeAll() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppTypography.inter(size: 16))
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()
                .overlay(AppColors.border)
        }
        .background(AppColors.cardBackground.opacity(0.6))
    }

    private func selectedTraitPill(category: String, value: String) -> some View {
        Button {
            withAnimation {
                var current = selectedTraits[category] ?? Set<String>()
                current.remove(value)
                if current.isEmpty {
                    _ = selectedTraits.removeValue(forKey: category)
                } else {
                    selectedTraits[category] = current
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(value)
                    .font(AppTypography.tagText)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(AppTypography.inter(size: 8, weight: .semibold))
            }
            .foregroundStyle(AppColors.primaryAmber)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.primaryAmber.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trait Collection Grid

    private var traitCollectionGrid: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(filteredSubcategoryGroups, id: \.question.title) { group in
                traitGroupSection(group)
            }
        }
    }

    private func traitGroupSection(_ group: TraitTermGroup) -> some View {
        let selectedValues: Set<String> = selectedTraits[group.question.category] ?? []
        let selectionCount: Int = selectedValues.count

        let illustrated = group.terms.filter {
            ($0.imageURL != nil && !($0.imageURL?.isEmpty ?? true)) ||
            ($0.colorImageURL != nil && !($0.colorImageURL?.isEmpty ?? true))
        }
        let textOnly = group.terms.filter {
            ($0.imageURL == nil || ($0.imageURL?.isEmpty ?? true)) &&
            ($0.colorImageURL == nil || ($0.colorImageURL?.isEmpty ?? true))
        }

        return VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack(spacing: 8) {
                Text(group.question.title)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(group.terms.count)")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.cardElevated)
                    .clipShape(Capsule())

                Spacer()

                if selectionCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(AppTypography.inter(size: 14))
                            .foregroundStyle(AppColors.primaryAmber)
                        if selectionCount > 1 {
                            Text("\(selectionCount)")
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.primaryAmber)
                        }
                    }
                }
            }

            // Illustrated grid — terms with images
            if !illustrated.isEmpty {
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(illustrated, id: \.term) { term in
                        illustratedTraitCell(
                            term: term,
                            isSelected: selectedValues.contains(term.term),
                            category: group.question.category
                        )
                    }
                }
            }

            // Text-only terms — no image, shown as selectable pills below the grid
            if !textOnly.isEmpty {
                if !illustrated.isEmpty {
                    Divider()
                        .overlay(AppColors.border)
                        .padding(.top, 2)
                }
                FlowLayout(spacing: 6) {
                    ForEach(textOnly, id: \.term) { term in
                        textOnlyTraitPill(
                            term: term,
                            isSelected: selectedValues.contains(term.term),
                            category: group.question.category
                        )
                    }
                }
            }
        }
    }

    private func textOnlyTraitPill(term: BotanyTerm, isSelected: Bool, category: String) -> some View {
        Text(term.term)
            .font(AppTypography.tagText)
            .foregroundStyle(isSelected ? AppColors.primaryAmber : AppColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? AppColors.primaryAmber.opacity(0.10) : AppColors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(
                        isSelected ? AppColors.primaryAmber : AppColors.border,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectTrait(category: category, value: term.term)
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                longPressedTerm = term
            }
    }

    // MARK: - Illustrated Trait Cell

    private func illustratedTraitCell(term: BotanyTerm, isSelected: Bool, category: String) -> some View {
        VStack(spacing: 4) {
            // Image area — AppColors.appBackground so image blends seamlessly
            ZStack(alignment: .topTrailing) {
                AppColors.appBackground
                    .overlay {
                        traitTermImage(term: term)
                    }
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))

                // Selection checkmark badge
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.inter(size: 18))
                        .foregroundStyle(AppColors.primaryAmber)
                        .background(
                            Circle()
                                .fill(AppColors.appBackground)
                                .frame(width: 16, height: 16)
                        )
                        .padding(5)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(isSelected ? AppColors.primaryAmber : Color.clear, lineWidth: 2)
            )

            // Label
            Text(term.term)
                .font(AppTypography.tagText)
                .foregroundStyle(isSelected ? AppColors.primaryAmber : AppColors.textSecondary)
                .lineLimit(1)
        }
        .padding(isSelected ? 4 : 0)
        .background(isSelected ? AppColors.primaryAmber.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: isSelected ? 10 : 0))
        .contentShape(Rectangle())
        .onTapGesture {
            selectTrait(category: category, value: term.term)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            longPressedTerm = term
        }
    }

    // MARK: - Trait Term Image

    /// Prefer line drawing for most organs; prefer color image for Fruit
    @ViewBuilder
    private func traitTermImage(term: BotanyTerm) -> some View {
        let bestURL: URL? = {
            if selectedOrgan == .fruit {
                if let c = term.colorImageURL, !c.isEmpty, let u = URL(string: c) { return u }
                if let d = term.imageURL, !d.isEmpty, let u = URL(string: d) { return u }
            } else {
                if let d = term.imageURL, !d.isEmpty, let u = URL(string: d) { return u }
                if let c = term.colorImageURL, !c.isEmpty, let u = URL(string: c) { return u }
            }
            return nil
        }()

        if let url = bestURL {
            ThrottledAsyncImage(url: url, contentMode: .fit) {
                traitPlaceholderIcon
            }
        } else {
            traitPlaceholderIcon
        }
    }

    private var traitPlaceholderIcon: some View {
        Image(systemName: selectedOrgan.icon)
            .font(.title3)
            .foregroundStyle(AppColors.textMuted.opacity(0.5))
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedOrgan.icon)
                .font(AppTypography.inter(size: 36))
                .foregroundStyle(AppColors.primaryAmber.opacity(0.6))

            Text("No Trait Options Available")
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)

            Text("There are no trait terms loaded for this category yet.")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    // MARK: - Coach Banner

    private struct CoachTip {
        let icon: String
        let text: String
    }

    private let coachTips: [CoachTip] = [
        CoachTip(icon: "hand.tap.fill", text: "Pick the plant part you're observing — leaf, flower, fruit, bark, stem, or root."),
        CoachTip(icon: "checkmark.square.fill", text: "Tap illustrated traits to select what matches your observation. Select as many as you can see."),
        CoachTip(icon: "hand.press.fill", text: "Hold any trait to learn more about the botanical trait. A detail page will open with definitions and examples."),
        CoachTip(icon: "sparkle.magnifyingglass", text: "Hit the match counter to see ranked species results. More traits = fewer, better matches.")
    ]

    private var observeCoachBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: coachTips[coachStep].icon)
                .font(AppTypography.inter(size: 18))
                .foregroundStyle(AppColors.primaryAmber)
                .frame(width: 32)

            Text(coachTips[coachStep].text)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .id(coachStep)

            Spacer(minLength: 0)

            Button {
                if coachStep < coachTips.count - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        coachStep += 1
                    }
                } else {
                    hasSeenObserveCoach = true
                    withAnimation(.easeIn(duration: 0.3)) {
                        showCoach = false
                    }
                }
            } label: {
                Text(coachStep < coachTips.count - 1 ? "Next" : "Memorized")
                    .font(AppTypography.inter(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.primaryAmber)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.primaryAmber.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(AppColors.primaryAmber.opacity(0.3))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Results Modal

    private var resultsModal: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                if selectedTraits.isEmpty {
                    // All traits removed — show empty state
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.circle")
                            .font(AppTypography.inter(size: 44))
                            .foregroundStyle(AppColors.textMuted.opacity(0.5))

                        Text("No traits selected")
                            .font(AppTypography.bodyText)
                            .foregroundStyle(AppColors.textSecondary)

                        Text("Go back to select traits and find matching species.")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            showResults = false
                        } label: {
                            Text("Select Traits")
                                .font(AppTypography.sectionHeader)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(AppColors.primaryAmber)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Interactive selected traits collection
                            selectedTraitsCollection
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 12)

                            Divider()
                                .overlay(AppColors.border)

                            if matchResults.isEmpty {
                                // Has traits but no matches
                                VStack(spacing: 16) {
                                    Spacer().frame(height: 60)

                                    Image(systemName: "magnifyingglass")
                                        .font(AppTypography.inter(size: 36))
                                        .foregroundStyle(AppColors.textMuted.opacity(0.5))

                                    Text("No matching species")
                                        .font(AppTypography.bodyText)
                                        .foregroundStyle(AppColors.textSecondary)

                                    Text("Try removing some traits to broaden your search.")
                                        .font(AppTypography.tagText)
                                        .foregroundStyle(AppColors.textMuted)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                let fullMatches = matchResults.filter { $0.matchPercentage == 100.0 }
                                let closeMatches = matchResults.filter { $0.matchPercentage < 100.0 }

                                // Results header
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: "leaf.fill")
                                        .font(AppTypography.inter(size: 13))
                                        .foregroundStyle(AppColors.success)

                                    Text("\(matchResults.count) Matching Species")
                                        .font(AppTypography.sectionHeader)
                                        .foregroundStyle(AppColors.textPrimary)

                                    Spacer()

                                    Text("by match %")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 8)

                                // Combined plant list for pager (full matches first, then close)
                                let allResultPlants = (fullMatches + closeMatches).map(\.plant)

                                // Full matches (0 contradictions)
                                ForEach(fullMatches) { result in
                                    let index = allResultPlants.firstIndex(where: { $0.id == result.plant.id }) ?? 0
                                    NavigationLink(destination: CollectionPagerView(items: allResultPlants, startIndex: index) { p in
                                        PlantDetailView(plant: p)
                                    }) {
                                        resultRow(result)
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Close matches section (1 contradiction)
                                if !closeMatches.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(AppTypography.inter(size: 10))
                                            .foregroundStyle(AppColors.primaryAmber)

                                        Text("Close Matches — 1 trait differs")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.textMuted)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, fullMatches.isEmpty ? 4 : 20)
                                    .padding(.bottom, 6)

                                    ForEach(closeMatches) { result in
                                        let index = allResultPlants.firstIndex(where: { $0.id == result.plant.id }) ?? 0
                                        NavigationLink(destination: CollectionPagerView(items: allResultPlants, startIndex: index) { p in
                                            PlantDetailView(plant: p)
                                        }) {
                                            resultRow(result)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedTraits.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTraits.removeAll()
                            }
                        } label: {
                            Text("Clear All")
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.primaryAmber)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showResults = false
                    }
                    .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Interactive Selected Traits Collection

    /// Grouped representation of selected traits for the results modal.
    private var selectedTraitsByOrgan: [(organ: String, icon: String, traits: [(id: String, category: String, value: String)])] {
        // Map each category to its parent organ for grouping
        let organForCategory: [String: PlantOrgan] = {
            var mapping: [String: PlantOrgan] = [:]
            for organ in PlantOrgan.allCases {
                for q in organ.traitQuestions {
                    mapping[q.category] = organ
                }
            }
            return mapping
        }()

        // Group selected traits by organ
        var organGroups: [String: [(id: String, category: String, value: String)]] = [:]
        var organIcons: [String: String] = [:]

        for (category, values) in selectedTraits.sorted(by: { $0.key < $1.key }) {
            let organ = organForCategory[category] ?? .leaf
            let organName = organ.rawValue
            organIcons[organName] = organ.icon

            let traitEntries = values.sorted().map { value in
                (id: "\(category)_\(value)", category: category, value: value)
            }

            organGroups[organName, default: []].append(contentsOf: traitEntries)
        }

        // Sort by organ order
        let organOrder = PlantOrgan.allCases.map(\.rawValue)
        return organOrder.compactMap { organName in
            guard let traits = organGroups[organName], !traits.isEmpty else { return nil }
            return (organ: organName, icon: organIcons[organName] ?? "leaf.fill", traits: traits)
        }
    }

    private var selectedTraitsCollection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(AppTypography.inter(size: 13))
                    .foregroundStyle(AppColors.primaryAmber)

                Text("Your Selections")
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("\(totalSelectionCount)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.primaryAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.primaryAmber.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("Tap a trait to remove and re-match")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted)

            // Traits grouped by organ
            ForEach(selectedTraitsByOrgan, id: \.organ) { group in
                VStack(alignment: .leading, spacing: 6) {
                    // Organ label
                    HStack(spacing: 5) {
                        Image(systemName: group.icon)
                            .font(AppTypography.inter(size: 11))
                            .foregroundStyle(AppColors.primaryAmber.opacity(0.7))
                        Text(group.organ)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    // Removable trait pills
                    FlowLayout(spacing: 6) {
                        ForEach(group.traits, id: \.id) { trait in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    removeTrait(category: trait.category, value: trait.value)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(trait.value)
                                        .font(AppTypography.tagText)
                                        .lineLimit(1)

                                    Image(systemName: "xmark")
                                        .font(AppTypography.inter(size: 8, weight: .bold))
                                }
                                .foregroundStyle(AppColors.primaryAmber)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppColors.primaryAmber.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.primaryAmber.opacity(0.25), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    /// Remove a single trait value from selected traits.
    private func removeTrait(category: String, value: String) {
        var current = selectedTraits[category] ?? Set<String>()
        current.remove(value)
        if current.isEmpty {
            _ = selectedTraits.removeValue(forKey: category)
        } else {
            selectedTraits[category] = current
        }
    }


    // MARK: - Result Row

    private func resultRow(_ result: PlantMatchResult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(matchColor(result.matchPercentage).opacity(0.3), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: result.matchPercentage / 100)
                    .stroke(matchColor(result.matchPercentage), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(result.matchPercentage))%")
                    .font(AppTypography.tagText)
                    .foregroundStyle(matchColor(result.matchPercentage))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(result.plant.scientificName)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)
                    .italic()

                Text(result.plant.titleCasedCommonName)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)

                Text("\(result.matchedTraits)/\(result.totalTraits) traits matched")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.inter(size: 12))
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
    }

    // MARK: - Logic

    private func termsForCategory(_ category: String) -> [BotanyTerm] {
        botanyTerms.filter { $0.category == category }
    }

    private func selectTrait(category: String, value: String) {
        // Auto-dismiss coach on first trait selection
        if showCoach {
            hasSeenObserveCoach = true
            withAnimation(.easeIn(duration: 0.3)) { showCoach = false }
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            var current = selectedTraits[category] ?? Set<String>()
            if current.contains(value) {
                current.remove(value)
                if current.isEmpty {
                    _ = selectedTraits.removeValue(forKey: category)
                } else {
                    selectedTraits[category] = current
                }
            } else {
                current.insert(value)
                selectedTraits[category] = current
            }
        }
    }

    private var todayQuestionCount: Int {
        refreshDailyCount()
        return observeQuestionsToday
    }

    private func refreshDailyCount() {
        let today = formattedToday
        if observeQuestionsDate != today {
            observeQuestionsToday = 0
            observeQuestionsDate = today
        }
    }

    private var formattedToday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func computeMatchingPlants() -> [PlantMatchResult] {
        guard !selectedTraits.isEmpty else { return [] }

        // Gather ALL questions across ALL organs so multi-organ selections count
        let allQuestions: [TraitQuestion] = PlantOrgan.allCases.flatMap { $0.traitQuestions }
        var results: [PlantMatchResult] = []

        for plant in plants {
            var matchedCount = 0
            var mismatchedCount = 0

            for question in allQuestions {
                guard let selectedValues = selectedTraits[question.category], !selectedValues.isEmpty else { continue }

                let plantValue = plant[keyPath: question.keyPath]

                if let plantValue, !plantValue.isEmpty {
                    // OR within category: plant matches if its value contains any selected value
                    let matched = selectedValues.contains { selected in
                        plantValue.localizedCaseInsensitiveContains(selected)
                    }
                    if matched {
                        matchedCount += 1
                    } else {
                        mismatchedCount += 1  // Confirmed contradiction
                    }
                }
                // Nil/empty = data gap in the database.
                // Absence of a recorded value is NOT a botanical contradiction —
                // don't penalise a species for an incomplete database entry.
            }

            // Must have at least 1 confirmed match to be a candidate at all
            guard matchedCount > 0 else { continue }

            // Full match: all documented traits agree, no contradictions
            // Close match: exactly 1 contradiction — surfaces cases where user may
            //   have misidentified a similar trait. Requires ≥2 confirmed matches
            //   so single-trait coincidences aren't surfaced as close matches.
            if mismatchedCount == 1 && matchedCount < 2 { continue }
            guard mismatchedCount <= 1 else { continue }

            // Score = confirmed matches / (confirmed matches + confirmed contradictions)
            // Data gaps are excluded from the denominator: they neither support nor rule out
            let totalKnown = matchedCount + mismatchedCount
            let percentage = Double(matchedCount) / Double(totalKnown) * 100.0

            results.append(PlantMatchResult(
                plant: plant,
                matchPercentage: percentage,
                matchedTraits: matchedCount,
                totalTraits: totalKnown
            ))
        }

        // Sort: highest score first, then most confirmed matches (evidence depth), then alphabetical
        return results.sorted {
            if $0.matchPercentage != $1.matchPercentage { return $0.matchPercentage > $1.matchPercentage }
            if $0.matchedTraits != $1.matchedTraits { return $0.matchedTraits > $1.matchedTraits }
            return $0.plant.scientificName < $1.plant.scientificName
        }
    }

    private func matchColor(_ percentage: Double) -> Color {
        if percentage == 100.0 {
            return .highConfidence   // No contradictions — full match
        } else {
            return .mediumConfidence // 1 confirmed contradiction — close match
        }
    }
}

// MARK: - Trait Term Group

private struct TraitTermGroup {
    let question: TraitQuestion
    let terms: [BotanyTerm]
}

// MARK: - Preview

#Preview {
    @State var showResults = false
    NavigationStack {
        ObserveView(showResults: $showResults)
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, BotanyTerm.self, JournalNote.self], inMemory: true)
    .preferredColorScheme(.dark)
}
