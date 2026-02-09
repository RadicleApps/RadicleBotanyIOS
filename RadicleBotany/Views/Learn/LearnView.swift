import SwiftUI
import SwiftData

struct LearnView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var plants: [Plant]
    @Query(sort: \Family.familyLatin) private var families: [Family]
    @Query(sort: \BotanyTerm.term) private var terms: [BotanyTerm]

    @State private var showPaywall = false

    private let categoryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                nowBloomingSection
                browseByCategorySection
                browseAllSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
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

    // MARK: - Now Blooming Section

    private var nowBloomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now Blooming")
                .font(AppFont.sectionHeader())
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        nowBloomingCard(index: index)
                    }
                }
            }
        }
    }

    private func nowBloomingCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.surfaceElevated)
                .frame(width: 150, height: 110)
                .overlay {
                    Image(systemName: "camera.macro")
                        .font(.title2)
                        .foregroundStyle(Color.greenSecondary.opacity(0.5))
                }

            Text("Seasonal Plant")
                .font(AppFont.caption())
                .foregroundStyle(Color.textPrimary)

            Text("Check back for seasonal blooms")
                .font(.system(size: 11))
                .foregroundStyle(Color.textMuted)
                .lineLimit(2)
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

            NavigationLink(destination: TermsListView()) {
                browseAllRow(
                    icon: "text.book.closed.fill",
                    title: "All Terms",
                    count: terms.count,
                    color: .orangePrimary
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
}

#Preview {
    NavigationStack {
        LearnView()
    }
    .environmentObject(StoreManager())
    .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self], inMemory: true)
    .preferredColorScheme(.dark)
}
