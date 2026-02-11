import SwiftUI
import SwiftData

struct ConservationView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var allPlants: [Plant] = []
    @State private var searchText = ""
    @State private var selectedFilter: UPSSpecies.UPSStatus? = nil

    private var filteredSpecies: [UPSSpecies] {
        var result = UPSData.allSpecies

        if let filter = selectedFilter {
            result = result.filter { $0.status == filter }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.commonName.localizedCaseInsensitiveContains(searchText) ||
                $0.scientificName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted {
            if $0.status.sortOrder != $1.status.sortOrder {
                return $0.status.sortOrder < $1.status.sortOrder
            }
            return $0.commonName < $1.commonName
        }
    }

    private var groupedSpecies: [(status: String, species: [UPSSpecies])] {
        let grouped = Dictionary(grouping: filteredSpecies) { $0.status.rawValue }
        let order: [String] = ["Critical", "At-Risk", "In Review"]
        return order.compactMap { status in
            guard let species = grouped[status], !species.isEmpty else { return nil }
            return (status: status, species: species)
        }
    }

    var body: some View {
        List {
            // Header info
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.arrow.triangle.circlepath")
                            .font(.title2)
                            .foregroundStyle(Color.greenSecondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("United Plant Savers")
                                .font(AppFont.sectionHeader(16))
                                .foregroundStyle(Color.textPrimary)

                            Text("Protecting native medicinal plants")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)
                        }
                    }

                    Text("UpS evaluates scientific research, environmental pressure, and industry demand to identify wild medicinal plants most sensitive to human activities.")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.surface)
            }

            // Filter chips
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "All", filter: nil, count: UPSData.allSpecies.count)
                        filterChip(title: "Critical", filter: .critical, count: UPSData.criticalSpecies.count)
                        filterChip(title: "At-Risk", filter: .atRisk, count: UPSData.atRiskSpecies.count)
                        filterChip(title: "In Review", filter: .inReview, count: UPSData.inReviewSpecies.count)
                    }
                }
                .listRowBackground(Color.appBackground)
                .listRowSeparator(.hidden)
            }

            // Species list
            ForEach(groupedSpecies, id: \.status) { group in
                Section {
                    ForEach(group.species) { species in
                        speciesRow(species)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(group.status)
                            .font(AppFont.sectionHeader())
                            .foregroundStyle(statusColor(group.status))

                        Text("\(group.species.count)")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Conservation")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search species...")
        .onAppear {
            allPlants = (try? modelContext.fetch(FetchDescriptor<Plant>())) ?? []
        }
    }

    // MARK: - Filter Chip

    private func filterChip(title: String, filter: UPSSpecies.UPSStatus?, count: Int) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(AppFont.caption())

                Text("\(count)")
                    .font(AppFont.caption(10))
            }
            .foregroundStyle(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.greenSecondary : Color.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Species Row

    private func speciesRow(_ species: UPSSpecies) -> some View {
        let matchedPlant = findMatchingPlant(species)

        return Group {
            if let plant = matchedPlant {
                NavigationLink(value: plant) {
                    speciesRowContent(species, isInApp: true)
                }
            } else {
                speciesRowContent(species, isInApp: false)
            }
        }
        .listRowBackground(Color.surface)
        .listRowSeparatorTint(Color.borderSubtle)
    }

    private func speciesRowContent(_ species: UPSSpecies, isInApp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(species.commonName)
                    .font(AppFont.body())
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                statusBadge(species.status)
            }

            Text(species.scientificName)
                .font(AppFont.italic(13))
                .foregroundStyle(Color.textMuted)

            Text(species.description)
                .font(AppFont.caption(11))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(2)
                .lineLimit(2)

            if isInApp {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 10))
                    Text("View in RadicleBotany")
                        .font(AppFont.caption(10))
                }
                .foregroundStyle(Color.greenSecondary)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: UPSSpecies.UPSStatus) -> some View {
        Text(status.rawValue)
            .font(AppFont.caption(10))
            .foregroundStyle(statusTextColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusTextColor(status).opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Critical": return .errorRed
        case "At-Risk": return .warningAmber
        case "In Review": return .purpleSecondary
        default: return .textSecondary
        }
    }

    private func statusTextColor(_ status: UPSSpecies.UPSStatus) -> Color {
        switch status {
        case .critical: return .errorRed
        case .atRisk: return .warningAmber
        case .inReview: return .purpleSecondary
        }
    }

    private func findMatchingPlant(_ species: UPSSpecies) -> Plant? {
        guard let matchName = UPSData.matchingPlantName(for: species) else { return nil }
        return allPlants.first { $0.scientificName == matchName }
    }
}

#Preview {
    NavigationStack {
        ConservationView()
    }
    .modelContainer(for: Plant.self, inMemory: true)
    .preferredColorScheme(.dark)
}
