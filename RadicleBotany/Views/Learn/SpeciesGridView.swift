import SwiftUI
import SwiftData

struct SpeciesGridView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext
    @State private var allPlants: [Plant] = []

    var filterCategory: String? = nil

    @State private var showPaywall = false
    @State private var searchText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Filtered Plants

    private var filteredPlants: [Plant] {
        var result = allPlants

        // Apply category filter
        if let category = filterCategory {
            switch category {
            case "Flowers":
                result = result.filter { $0.flowerColor != nil && !($0.flowerColor?.isEmpty ?? true) }
            case "Leaves":
                result = result.filter { $0.leafType != nil && !($0.leafType?.isEmpty ?? true) }
            case "Fruits":
                result = result.filter { $0.fruitType != nil && !($0.fruitType?.isEmpty ?? true) }
            case "Bark":
                result = result.filter {
                    ($0.stemStructure != nil && !($0.stemStructure?.isEmpty ?? true)) ||
                    ($0.stemHabit != nil && !($0.stemHabit?.isEmpty ?? true))
                }
            case "Stems":
                result = result.filter { $0.stemStructure != nil && !($0.stemStructure?.isEmpty ?? true) }
            default:
                break
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.scientificName.localizedCaseInsensitiveContains(searchText) ||
                $0.commonName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredPlants) { plant in
                    plantCell(plant)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle(navigationTitle)
        .searchable(text: $searchText, prompt: "Search species...")
        .navigationDestination(for: Plant.self) { plant in
            PlantDetailView(plant: plant)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear { loadData() }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let category = filterCategory {
            return category
        }
        return "Species"
    }

    // MARK: - Plant Cell

    private func loadData() {
        allPlants = (try? modelContext.fetch(FetchDescriptor<Plant>(sortBy: [SortDescriptor(\Plant.scientificName)]))) ?? []
    }

    private func plantCell(_ plant: Plant) -> some View {
        let isUnlocked = plant.isFree || storeManager.isFeatureUnlocked(.fullSpeciesAccess)

        return Group {
            if isUnlocked {
                NavigationLink(value: plant) {
                    plantCellContent(plant: plant, isLocked: false)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    plantCellContent(plant: plant, isLocked: true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func plantCellContent(plant: Plant, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.surfaceElevated)
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay {
                        Image(systemName: "leaf.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.greenSecondary.opacity(0.3))
                    }

                if isLocked {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.surfaceElevated)
                        .aspectRatio(1.0, contentMode: .fit)
                        .blur(radius: 4)

                    LockOverlay()
                }
            }

            // Plant info
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.scientificName)
                    .font(AppFont.italic(13))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(plant.commonName)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            // At risk badge
            if plant.isAtRisk, let status = plant.atRiskStatus {
                AtRiskBadge(status: status)
            }
        }
        .cardStyle(padding: 8)
    }
}

#Preview {
    NavigationStack {
        SpeciesGridView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: Plant.self, inMemory: true)
    .preferredColorScheme(.dark)
}
