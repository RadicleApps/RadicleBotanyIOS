import SwiftUI
import SwiftData

struct TermsListView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \BotanyTerm.term) private var terms: [BotanyTerm]

    @State private var showPaywall = false
    @State private var searchText = ""

    // MARK: - Computed Properties

    private var filteredTerms: [BotanyTerm] {
        if searchText.isEmpty {
            return terms
        }
        return terms.filter {
            $0.term.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTerms: [(category: String, terms: [BotanyTerm])] {
        let grouped = Dictionary(grouping: filteredTerms) { $0.category }

        return grouped
            .map { (category: $0.key, terms: $0.value.sorted { $0.term < $1.term }) }
            .sorted { $0.category < $1.category }
    }

    private var hasFullAccess: Bool {
        storeManager.isFeatureUnlocked(.fullTermAccess)
    }

    var body: some View {
        List {
            ForEach(groupedTerms, id: \.category) { group in
                Section {
                    ForEach(group.terms) { term in
                        termRow(term)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(group.category)
                            .font(AppFont.sectionHeader())
                            .foregroundStyle(Color.orangePrimary)

                        Text("\(group.terms.count)")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Botanical Terms")
        .searchable(text: $searchText, prompt: "Search terms...")
        .navigationDestination(for: BotanyTerm.self) { term in
            TermDetailView(term: term)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Term Row

    private func termRow(_ term: BotanyTerm) -> some View {
        let isUnlocked = term.isFree || hasFullAccess

        return Group {
            if isUnlocked {
                NavigationLink(value: term) {
                    termRowContent(term)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    termRowContent(term, showLock: true)
                }
            }
        }
        .listRowBackground(Color.surface)
        .listRowSeparatorTint(Color.borderSubtle)
    }

    private func termRowContent(_ term: BotanyTerm, showLock: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(term.term)
                    .font(AppFont.body())
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)

                CategoryPill(text: term.category, color: categoryColor(for: term.category))
            }

            Spacer()

            if showLock {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textMuted)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case let c where c.contains("leaf") || c.contains("leaves"):
            return .greenSecondary
        case let c where c.contains("flower"):
            return .orangePrimary
        case let c where c.contains("fruit"):
            return .warningAmber
        case let c where c.contains("stem") || c.contains("bark"):
            return .orangeLight
        case let c where c.contains("root"):
            return .greenLight
        default:
            return .purpleSecondary
        }
    }
}

#Preview {
    NavigationStack {
        TermsListView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: BotanyTerm.self, inMemory: true)
    .preferredColorScheme(.dark)
}
