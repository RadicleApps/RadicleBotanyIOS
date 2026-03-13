import SwiftUI
import SwiftData

struct BloomCalendarView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    private let columns = [
        GridItem(.flexible())
    ]

    private let monthNames = Calendar.current.monthSymbols
    private let currentMonth = Calendar.current.component(.month, from: Date())

    // MARK: - Cached Data (computed once, updated on change)

    @State private var cachedBloomCounts: [Int: Int] = [:]
    @State private var cachedBloomingPlants: [Plant] = []
    @State private var cachedPlantsWithBloom: [Plant] = []

    private func recomputeBloomData() {
        cachedPlantsWithBloom = allPlants.filter { !$0.bloomMonthArray.isEmpty }
        var counts: [Int: Int] = [:]
        for month in 1...12 {
            counts[month] = cachedPlantsWithBloom.filter { $0.bloomMonthArray.contains(month) }.count
        }
        cachedBloomCounts = counts
        cachedBloomingPlants = cachedPlantsWithBloom.filter { $0.bloomMonthArray.contains(selectedMonth) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            monthSelector

            resultHeader
                .padding(.horizontal, 16)
                .padding(.top, 8)

            if cachedBloomingPlants.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(cachedBloomingPlants) { plant in
                            bloomPlantCell(plant)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.bloomCalendar)
        .onAppear { if cachedPlantsWithBloom.isEmpty { recomputeBloomData() } }
        .onChange(of: selectedMonth) { _, _ in
            cachedBloomingPlants = cachedPlantsWithBloom.filter { $0.bloomMonthArray.contains(selectedMonth) }
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...12, id: \.self) { month in
                        monthChip(month: month)
                            .id(month)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onAppear {
                withAnimation {
                    proxy.scrollTo(selectedMonth, anchor: .center)
                }
            }
        }
    }

    private func monthChip(month: Int) -> some View {
        let isSelected = month == selectedMonth
        let isCurrent = month == currentMonth
        let count = cachedBloomCounts[month] ?? 0

        let bgColor: Color = isSelected ? .orangePrimary : AppColors.cardElevated
        let fgColor: Color = isSelected ? .white : AppColors.textSecondary
        let borderColor: Color = isSelected ? .orangePrimary : (isCurrent ? .orangePrimary.opacity(0.5) : AppColors.border)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMonth = month
            }
        } label: {
            VStack(spacing: 4) {
                Text(String(monthNames[month - 1].prefix(3)))
                    .font(AppTypography.tagText)
                    .foregroundStyle(fgColor)

                if isCurrent && !isSelected {
                    Text("Now")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.primaryAmber)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "leaf.fill")
                            .font(AppTypography.inter(size: 6))
                        Text("\(count)")
                            .font(AppTypography.tagText)
                    }
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : AppColors.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(borderColor, lineWidth: isCurrent ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        HStack {
            Text("\(cachedBloomingPlants.count) species blooming in \(monthNames[selectedMonth - 1])")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            if selectedMonth == currentMonth {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.primaryAmber)
                        .frame(width: 6, height: 6)
                    Text("Current month")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Bloom Plant Cell

    private func bloomPlantCell(_ plant: Plant) -> some View {
        let index = cachedBloomingPlants.firstIndex(where: { $0.id == plant.id }) ?? 0
        return NavigationLink(destination: CollectionPagerView(items: cachedBloomingPlants, startIndex: index) { p in
            PlantDetailView(plant: p)
        }) {
            bloomCellContent(plant: plant, isLocked: false)
        }
        .buttonStyle(BloomCellButtonStyle())
    }

    private func bloomCellContent(plant: Plant, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Common name
            Text(plant.titleCasedCommonName)
                .font(AppTypography.bodyText)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            // Scientific name
            Text(plant.scientificName)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)

            // Bloom badges
            HStack(spacing: 4) {
                if let bloomText = plant.bloomPeriodText {
                    Text(bloomText)
                        .font(AppTypography.inter(size: 9, weight: .medium))
                        .foregroundStyle(AppColors.primaryAmber)
                }

                if plant.bloomMonthArray.contains(currentMonth) {
                    Text("Now")
                        .font(AppTypography.inter(size: 8, weight: .bold))
                        .foregroundStyle(AppColors.success)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.success.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("sunflower head inflor")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .opacity(0.5)

            Text("No blooms in \(monthNames[selectedMonth - 1])")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary)

            Text("Try selecting a different month")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}

// MARK: - Bloom Cell Press Style

private struct BloomCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        BloomCalendarView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: Plant.self, inMemory: true)
    .preferredColorScheme(.dark)
}
