import SwiftUI
import SwiftData

struct FamiliesListView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext
    @State private var families: [Family] = []

    @State private var showPaywall = false
    @State private var searchText = ""

    // MARK: - Computed Properties

    private var filteredFamilies: [Family] {
        if searchText.isEmpty {
            return families
        }
        return families.filter {
            $0.familyLatin.localizedCaseInsensitiveContains(searchText) ||
            $0.familyEnglish.localizedCaseInsensitiveContains(searchText)
        }
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

    var body: some View {
        List {
            ForEach(groupedFamilies, id: \.letter) { group in
                Section {
                    ForEach(group.families) { family in
                        familyRow(family)
                    }
                } header: {
                    Text(group.letter)
                        .font(AppFont.sectionHeader())
                        .foregroundStyle(Color.orangePrimary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Families")
        .searchable(text: $searchText, prompt: "Search families...")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear { loadData() }
    }

    // MARK: - Family Row

    private func familyRow(_ family: Family) -> some View {
        Group {
            if isUnlocked {
                NavigationLink(destination: FamilyDetailView(family: family)) {
                    familyRowContent(family)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    familyRowContent(family, showLock: true)
                }
            }
        }
        .listRowBackground(Color.surface)
        .listRowSeparatorTint(Color.borderSubtle)
    }

    private func familyRowContent(_ family: Family, showLock: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(family.familyLatin)
                    .font(AppFont.body())
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)

                Text(family.familyEnglish)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            // Genera count
            let generaCount = generaCount(for: family)
            if generaCount > 0 {
                Text("\(generaCount) genera")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }

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

    private func loadData() {
        families = (try? modelContext.fetch(FetchDescriptor<Family>(sortBy: [SortDescriptor(\Family.familyLatin)]))) ?? []
    }

    private func generaCount(for family: Family) -> Int {
        guard !family.genera.isEmpty else { return 0 }
        let components = family.genera
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return components.count
    }
}

#Preview {
    NavigationStack {
        FamiliesListView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: Family.self, inMemory: true)
    .preferredColorScheme(.dark)
}
