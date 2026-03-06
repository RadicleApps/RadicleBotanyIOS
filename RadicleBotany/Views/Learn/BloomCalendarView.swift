import SwiftUI
import SwiftData

struct BloomCalendarView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Query(sort: \Plant.scientificName) private var allPlants: [Plant]

    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    private let columns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5)
    ]

    private let monthNames = Calendar.current.monthSymbols
    private let currentMonth = Calendar.current.component(.month, from: Date())

    // MARK: - Computed Properties

    private var plantsWithBloomData: [Plant] {
        allPlants.filter { !$0.bloomMonthArray.isEmpty }
    }

    private var bloomingPlants: [Plant] {
        plantsWithBloomData.filter { $0.bloomMonthArray.contains(selectedMonth) }
    }

    private var monthBloomCounts: [Int: Int] {
        var counts: [Int: Int] = [:]
        for month in 1...12 {
            counts[month] = plantsWithBloomData.filter { $0.bloomMonthArray.contains(month) }.count
        }
        return counts
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            monthSelector

            resultHeader
                .padding(.horizontal, 16)
                .padding(.top, 8)

            if bloomingPlants.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 1.5) {
                        ForEach(bloomingPlants) { plant in
                            bloomPlantCell(plant)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("Bloom Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.bloomCalendar)
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
        let count = monthBloomCounts[month] ?? 0

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
            Text("\(bloomingPlants.count) species blooming in \(monthNames[selectedMonth - 1])")
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
        NavigationLink(destination: PlantDetailView(plant: plant)) {
            bloomCellContent(plant: plant, isLocked: false)
        }
        .buttonStyle(BloomCellButtonStyle())
    }

    private func bloomCellContent(plant: Plant, isLocked: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Square image — cached first, then URL fallback
                CachedPlantGridImage(plant: plant, size: geo.size.width)

                // Bottom label overlay
                VStack(spacing: 2) {
                    Text(plant.commonName)
                        .font(AppTypography.tagText)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(plant.scientificName)
                        .font(.system(size: 10, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    // Bloom badges
                    HStack(spacing: 4) {
                        if let bloomText = plant.bloomPeriodText {
                            Text(bloomText)
                                .font(AppTypography.inter(size: 8, weight: .medium))
                                .foregroundStyle(AppColors.primaryAmber)
                        }

                        if plant.bloomMonthArray.contains(currentMonth) {
                            Text("· Blooming Now")
                                .font(AppTypography.inter(size: 8, weight: .bold))
                                .foregroundStyle(AppColors.success)
                        }
                    }
                    .padding(.top, 1)
                }
                .frame(width: geo.size.width, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Lock overlay
                if isLocked {
                    Color.black.opacity(0.55)
                        .frame(width: geo.size.width, height: geo.size.width)
                    Image(systemName: "lock.fill")
                        .font(AppTypography.inter(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: geo.size.width, height: geo.size.width)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
    }

    private func bloomCellPlaceholder(size: CGFloat) -> some View {
        AppColors.cardElevated
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "camera.macro")
                    .font(AppTypography.inter(size: 28))
                    .foregroundStyle(AppColors.primaryAmber.opacity(0.2))
            }
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
