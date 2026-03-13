import SwiftUI

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
        switch self {
        case .botany: return .orangePrimary
        case .family: return .purpleSecondary
        case .species: return .greenSecondary
        }
    }
}

// MARK: - Flashcard Hub View

struct FlashcardHubView: View {
    @State private var selectedDeck: FlashcardDeck = .botany

    var body: some View {
        VStack(spacing: 0) {
            // Deck toggle pills
            deckToggle
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Active deck content — frame(maxHeight: .infinity) constrains the inner
            // ScrollView to the remaining space so it scrolls correctly
            Group {
                switch selectedDeck {
                case .botany:
                    FlashcardView()
                case .family:
                    FamilyFlashcardView()
                case .species:
                    PlantFlashcardView()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .featureGuide(.flashCards)
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
                    .foregroundStyle(selectedDeck == deck ? deck.color : AppColors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        selectedDeck == deck
                            ? deck.color.opacity(0.14)
                            : AppColors.cardElevated
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedDeck == deck ? deck.color.opacity(0.35) : Color.clear, lineWidth: 0.5)
                    )
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
