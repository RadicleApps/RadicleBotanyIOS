import SwiftUI

// MARK: - Botanize Mode

enum BotanizeMode: String, CaseIterable, Identifiable {
    case observe = "Observe"
    case capture = "Capture"
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
        case .capture: return .capture
        case .both: return .bothMode
        }
    }
}

// MARK: - BotanizeView

struct BotanizeView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var selectedMode: BotanizeMode = .observe
    @State private var showPaywall = false
    @State private var paywallContext: String?

    var body: some View {
        VStack(spacing: 0) {
            modeSelector
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Divider()
                .overlay(Color.borderSubtle)

            // Content area
            Group {
                switch selectedMode {
                case .observe:
                    ObserveView()

                case .capture:
                    if storeManager.isFeatureUnlocked(.capture) {
                        CaptureView()
                    } else {
                        lockedPlaceholder(
                            mode: .capture,
                            description: "Use AI-powered plant identification to snap a photo and instantly identify species."
                        )
                    }

                case .both:
                    if storeManager.isFeatureUnlocked(.bothMode) {
                        BothModeView()
                    } else {
                        lockedPlaceholder(
                            mode: .both,
                            description: "Combine camera identification with trait verification for the most accurate results."
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle("Botanize")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(contextText: paywallContext)
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
        .background(Color.surface)
        .clipShape(Capsule())
    }

    private func modePill(_ mode: BotanizeMode) -> some View {
        let isSelected = selectedMode == mode
        let isLocked: Bool = {
            guard let feature = mode.requiredFeature else { return false }
            return !storeManager.isFeatureUnlocked(feature)
        }()

        return Button {
            if isLocked {
                paywallContext = "Upgrade to Pro to unlock \(mode.rawValue) mode."
                showPaywall = true
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedMode = mode
                }
            }
        } label: {
            HStack(spacing: 5) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.textMuted)
                }

                Image(systemName: mode.icon)
                    .font(.system(size: 12))

                Text(mode.rawValue)
                    .font(AppFont.sectionHeader())
            }
            .foregroundStyle(isSelected ? Color.textPrimary : (isLocked ? Color.textMuted : Color.textSecondary))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isSelected ? Color.surfaceElevated : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Locked Placeholder

    private func lockedPlaceholder(mode: BotanizeMode, description: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.surfaceElevated)
                        .frame(width: 80, height: 80)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.orangePrimary)
                }

                Text("\(mode.rawValue) Mode")
                    .font(AppFont.title(22))
                    .foregroundStyle(Color.textPrimary)

                Text(description)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                CategoryPill(text: "PRO", color: .greenSecondary)
            }

            Button {
                paywallContext = "Upgrade to Pro to unlock \(mode.rawValue) mode."
                showPaywall = true
            } label: {
                Text("Unlock \(mode.rawValue) Mode")
            }
            .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BotanizeView()
    }
    .environmentObject(StoreManager())
    .preferredColorScheme(.dark)
}
