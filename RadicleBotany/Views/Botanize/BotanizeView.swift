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
    @State private var selectedMode: BotanizeMode = .observe
    @AppStorage("hasSeenBotanizeOnboarding") private var hasSeenBotanizeOnboarding = false
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
                    ObserveView()

                case .capture:
                    CaptureView()

                case .both:
                    BothModeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.appBackground)
        .navigationTitle("Botanize")
        .navigationBarTitleDisplayMode(.inline)
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
    .preferredColorScheme(.dark)
}
