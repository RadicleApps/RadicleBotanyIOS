import SwiftUI
import SwiftData

// MARK: - Deck Type Enum

enum FlashcardDeck: String, CaseIterable {
    case botany, family, species

    var title: String {
        switch self {
        case .botany: return "Botany"
        case .family: return "Family"
        case .species: return "Species"
        }
    }

    var icon: String {
        switch self {
        case .botany: return "text.book.closed.fill"
        case .family: return "leaf.circle.fill"
        case .species: return "leaf.fill"
        }
    }

    var color: Color {
        return .orangePrimary
    }
}

// MARK: - Flashcard Hub View

struct FlashcardHubView: View {
    @State private var selectedDeck: FlashcardDeck = .botany
    @Query private var userSettingsResults: [UserSettings]
    @Query private var flashcardProgress: [FlashcardProgress]

    private var userSettings: UserSettings? { userSettingsResults.first }

    private var totalMastered: Int {
        flashcardProgress.filter { $0.status == "known" }.count
    }

    private var totalCards: Int {
        flashcardProgress.count
    }

    private var masteryPercent: Int {
        guard totalCards > 0 else { return 0 }
        return Int(Double(totalMastered) / Double(totalCards) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats header
            statsHeader
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Deck toggle pills
            deckToggle
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            // Active deck content
            switch selectedDeck {
            case .botany:
                FlashcardView()
            case .family:
                FamilyFlashcardView()
            case .species:
                PlantFlashcardView()
            }
        }
        .background(AppColors.appBackground)
        .navigationTitle("\(selectedDeck.title) Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.flashCards)
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statPill(
                icon: "flame.fill",
                value: "\(userSettings?.safeStudyStreak ?? 0)",
                label: "Streak",
                color: .orangePrimary
            )

            Spacer()

            statPill(
                icon: "star.fill",
                value: formatXP(userSettings?.safeTotalXP ?? 0),
                label: "XP",
                color: .orangePrimary
            )

            Spacer()

            statPill(
                icon: "chart.bar.fill",
                value: "\(masteryPercent)%",
                label: "Mastery",
                color: .orangePrimary
            )
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 11))
                .foregroundStyle(color)

            Text(value)
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.cardElevated)
        .clipShape(Capsule())
    }

    // MARK: - Deck Toggle

    private var deckToggle: some View {
        HStack(spacing: 8) {
            ForEach(FlashcardDeck.allCases, id: \.rawValue) { deck in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDeck = deck
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: deck.icon)
                            .font(AppTypography.inter(size: 12))

                        Text(deck.title)
                            .font(AppTypography.buttonText)
                    }
                    .foregroundStyle(selectedDeck == deck ? .white : AppColors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        selectedDeck == deck
                            ? deck.color
                            : AppColors.cardElevated
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardHubView()
    }
    .environmentObject(StoreManager(preview: true))
    .modelContainer(for: [Plant.self, Family.self, BotanyTerm.self, FlashcardProgress.self, UserSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
