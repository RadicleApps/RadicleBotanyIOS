import SwiftUI

// MARK: - Botanize Mode

enum BotanizeMode: String, CaseIterable, Identifiable {
    case capture = "Snap"
    case observe = "Observe"
    case both = "Both"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .observe: return "eye.fill"
        case .capture: return "camera.fill"
        case .both: return "sparkles"
        }
    }

    var requiredFeature: Feature? {
        switch self {
        case .observe: return nil
        case .capture: return nil  // Screen is free; camera is gated inside CaptureView
        case .both: return .bothMode
        }
    }
}

// MARK: - BotanizeView

struct BotanizeView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var navigationState: AppNavigationState
    @State private var selectedMode: BotanizeMode = .observe
    @AppStorage("hasSeenBotanizeOnboarding") private var hasSeenBotanizeOnboarding = false

    // Observe mode Matches pill state (communicated up from ObserveView)
    @State private var observeShowResults = false
    @State private var observeMatchCount = 0
    @State private var observeHasTraits = false

    var body: some View {
        VStack(spacing: 0) {
            modeSelector
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Divider()
                .overlay(AppColors.border)

            // Content area
            Group {
                switch selectedMode {
                case .observe:
                    ObserveView(
                        showResults: $observeShowResults,
                        onMatchStateChanged: { count, hasTraits in
                            observeMatchCount = count
                            observeHasTraits = hasTraits
                        }
                    )

                case .capture:
                    CaptureView()

                case .both:
                    BothModeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .appToolbar(guide: .botanize) {
            if selectedMode == .observe && observeHasTraits {
                Button {
                    observeShowResults = true
                } label: {
                    Text("\(observeMatchCount) Matches")
                        .font(AppTypography.sectionHeader)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppColors.success)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    navigationState.showProfile = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(AppTypography.inter(size: 15))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 32, height: 32)
                        .background(AppColors.cardElevated)
                        .clipShape(Circle())
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { !hasSeenBotanizeOnboarding },
            set: { if !$0 { hasSeenBotanizeOnboarding = true } }
        )) {
            BotanizeOnboardingView()
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 4) {
            ForEach(BotanizeMode.allCases) { mode in
                modePill(mode)
            }
        }
        .padding(3)
        .background(AppColors.cardBackground)
        .clipShape(Capsule())
    }

    private func modePill(_ mode: BotanizeMode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(AppTypography.inter(size: 12))

                Text(mode.rawValue)
                    .font(AppTypography.sectionHeader)
            }
            .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isSelected ? AppColors.cardElevated : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Preview

#Preview {
    NavigationStack {
        BotanizeView()
    }
    .environmentObject(StoreManager(preview: true))
    .environmentObject(AppNavigationState())
    .preferredColorScheme(.dark)
}
