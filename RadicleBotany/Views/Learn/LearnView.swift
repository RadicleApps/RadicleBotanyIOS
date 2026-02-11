import SwiftUI
import SwiftData

struct LearnView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext
    @State private var plants: [Plant] = []
    @State private var families: [Family] = []
    @State private var terms: [BotanyTerm] = []

    @State private var showPaywall = false

    private let categoryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    plantsNearMeSection
                    browseByCategorySection
                    browseAllSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color.appBackground)

            // Floating Flashcards button
            NavigationLink(destination: FlashcardsView()) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Flashcards")
                        .font(AppFont.sectionHeader())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.purpleSecondary)
                .clipShape(Capsule())
                .shadow(color: Color.purpleSecondary.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .onAppear { loadData() }
        .navigationTitle("Learn")
        .navigationDestination(for: Plant.self) { plant in
            PlantDetailView(plant: plant)
        }
        .navigationDestination(for: Family.self) { family in
            FamilyDetailView(family: family)
        }
        .navigationDestination(for: BotanyTerm.self) { term in
            TermDetailView(term: term)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Plants Near Me Section

    private var plantsNearMeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plants Near Me")
                    .font(AppFont.sectionHeader())
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer()

                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.greenSecondary)

                Text("Common species")
                    .font(AppFont.caption(10))
                    .foregroundStyle(Color.textMuted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(nearMePlants) { plant in
                        NavigationLink(value: plant) {
                            nearMeCard(plant)
                        }
                    }
                }
            }
        }
    }

    private var nearMePlants: [Plant] {
        plants.filter { $0.isFree && $0.habitat != nil && !($0.habitat?.isEmpty ?? true) }
            .prefix(8)
            .map { $0 }
    }

    private func nearMeCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.surfaceElevated)
                    .frame(width: 150, height: 110)
                    .overlay {
                        Image(systemName: "leaf.fill")
                            .font(.title2)
                            .foregroundStyle(Color.greenSecondary.opacity(0.3))
                    }

                if plant.isAtRisk, let status = plant.atRiskStatus {
                    VStack {
                        HStack {
                            Spacer()
                            AtRiskBadge(status: status)
                                .scaleEffect(0.8)
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }

            Text(plant.commonName)
                .font(AppFont.caption())
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(plant.scientificName)
                .font(AppFont.caption(10))
                .foregroundStyle(Color.textMuted)
                .italic()
                .lineLimit(1)
        }
        .frame(width: 150)
        .cardStyle(padding: 10)
    }

    // MARK: - Browse by Category Section

    private var browseByCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Category")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)

            LazyVGrid(columns: categoryColumns, spacing: 12) {
                categoryCard(title: "Flowers", icon: "camera.macro", color: .orangePrimary, category: "Flowers")
                categoryCard(title: "Leaves", icon: "leaf.fill", color: .greenSecondary, category: "Leaves")
                categoryCard(title: "Fruits", icon: "apple.logo", color: .warningAmber, category: "Fruits")
                categoryCard(title: "Bark", icon: "tree.fill", color: .orangeLight, category: "Bark")
                categoryCard(title: "Stems", icon: "arrow.up.and.line.horizontal.and.arrow.down", color: .greenLight, category: "Stems")
                categoryCard(title: "Families", icon: "rectangle.3.group.fill", color: .purpleSecondary, category: "Families")
            }
        }
    }

    private func categoryCard(title: String, icon: String, color: Color, category: String) -> some View {
        Group {
            if category == "Families" {
                NavigationLink(destination: FamiliesListView()) {
                    categoryCardContent(title: title, icon: icon, color: color)
                }
            } else {
                NavigationLink(destination: SpeciesGridView(filterCategory: category)) {
                    categoryCardContent(title: title, icon: icon, color: color)
                }
            }
        }
    }

    private func categoryCardContent(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle(padding: 12)
    }

    // MARK: - Browse All Section

    private var browseAllSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse All")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)

            NavigationLink(destination: TermsListView()) {
                browseAllRow(
                    icon: "text.book.closed.fill",
                    title: "All Terms",
                    count: terms.count,
                    color: .orangePrimary
                )
            }

            NavigationLink(destination: SpeciesGridView()) {
                browseAllRow(
                    icon: "leaf.fill",
                    title: "All Species",
                    count: plants.count,
                    color: .greenSecondary
                )
            }

            NavigationLink(destination: FamiliesListView()) {
                browseAllRow(
                    icon: "rectangle.3.group.fill",
                    title: "All Families",
                    count: families.count,
                    color: .purpleSecondary
                )
            }

            NavigationLink(destination: ConservationView()) {
                browseAllRow(
                    icon: "leaf.arrow.triangle.circlepath",
                    title: "Conservation",
                    count: UPSData.allSpecies.count,
                    color: .successGreen
                )
            }
        }
    }

    private func browseAllRow(icon: String, title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("\(title) (\(count))")
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textMuted)
        }
        .cardStyle()
    }

    private func loadData() {
        plants = (try? modelContext.fetch(FetchDescriptor<Plant>(sortBy: [SortDescriptor(\Plant.scientificName)]))) ?? []
        families = (try? modelContext.fetch(FetchDescriptor<Family>(sortBy: [SortDescriptor(\Family.familyLatin)]))) ?? []
        terms = (try? modelContext.fetch(FetchDescriptor<BotanyTerm>(sortBy: [SortDescriptor(\BotanyTerm.term)]))) ?? []
    }
}

#Preview {
    NavigationStack {
        LearnView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self], inMemory: true)
    .preferredColorScheme(.dark)
}
