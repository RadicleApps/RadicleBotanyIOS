import SwiftUI

struct BotanizingListView: View {
    @EnvironmentObject var storeManager: StoreManager

    @State private var scenarios: [BotanizingScenario] = []
    @State private var selectedCategory: ScenarioCategory? = nil
    @AppStorage("botanizing_completed") private var completedIds: String = ""

    private var completedSet: Set<String> {
        Set(completedIds.split(separator: ",").map(String.init))
    }

    private var filteredScenarios: [BotanizingScenario] {
        guard let cat = selectedCategory else { return scenarios }
        return scenarios.filter { $0.categoryType == cat }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section header
                VStack(spacing: 6) {
                    Text("FIELD SCENARIOS")
                        .font(AppTypography.inter(size: 11, weight: .heavy))
                        .tracking(2.5)
                        .foregroundStyle(AppColors.primaryAmber)

                    Text("Botanizing")
                        .font(.cormorant(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Practice botanical observation skills")
                        .font(AppTypography.inter(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Stats ribbon
                statsRibbon

                // Category filter chips
                categoryChips

                // Scenario grid
                scenarioGrid
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if scenarios.isEmpty {
                scenarios = BotanizingDataLoader.shared.loadScenarios()
            }
        }
    }

    // MARK: - Stats Ribbon

    private var statsRibbon: some View {
        HStack(spacing: 0) {
            statCell(value: "\(scenarios.count)", label: "Scenarios")
            Rectangle()
                .fill(AppColors.border)
                .frame(width: 0.5, height: 28)
            statCell(value: "\(categories.count)", label: "Categories")
        }
        .padding(.vertical, 8)
    }

    private func statCell(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(AppTypography.inter(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.primaryAmber)
            Text(label)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Chips

    private var categories: [ScenarioCategory] {
        let present = Set(scenarios.map { $0.categoryType })
        return ScenarioCategory.allCases.filter { present.contains($0) }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(categories, id: \.self) { cat in
                    chipButton(label: cat.label, isSelected: selectedCategory == cat) {
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                }
            }
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.chipText)
            .foregroundStyle(isSelected ? AppColors.onAccent : AppColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? AppColors.primaryAmber : AppColors.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scenario Grid

    private var scenarioGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredScenarios) { scenario in
                NavigationLink(destination: BotanizingScenarioView(scenario: scenario)) {
                    scenarioCard(scenario)
                }
                .buttonStyle(ScenarioCardButtonStyle())
            }
        }
    }

    private func scenarioCard(_ scenario: BotanizingScenario) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(scenario.title)
                .font(.cormorant(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Subtitle
            Text(scenario.subtitle)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Footer: difficulty + time
            HStack(spacing: 6) {
                Text(scenario.difficulty)
                    .font(AppTypography.inter(size: 10))
                    .fontWeight(.semibold)
                    .foregroundStyle(scenario.difficultyLevel.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(scenario.difficultyLevel.color.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(AppTypography.inter(size: 10))
                    Text("\(scenario.estimatedMinutes) min")
                        .font(AppTypography.inter(size: 10))
                }
                .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Button Style

private struct ScenarioCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        BotanizingListView()
    }
    .environmentObject(StoreManager(preview: true))
    .preferredColorScheme(.dark)
}
