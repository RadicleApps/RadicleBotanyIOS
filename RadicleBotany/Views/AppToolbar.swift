import SwiftUI

// MARK: - App Toolbar Modifier

/// Applies the shared top toolbar (chat + search + trailing action)
/// to any NavigationStack. Compact layout prevents cramping.
struct AppToolbarModifier<Trailing: View>: ViewModifier {
    @EnvironmentObject var navigationState: AppNavigationState
    let guide: FeatureGuide?
    let trailing: Trailing

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading: Optional contextual help button (per-tab)
                ToolbarItem(placement: .topBarLeading) {
                    if let guide {
                        InfoButton(guide: guide, style: .toolbar)
                    }
                }

                // Center: RadicleBotany wordmark — Cormorant Garamond italic serif
                ToolbarItem(placement: .principal) {
                    Text("RadicleBotany")
                        .font(.cormorant(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                }

                // Trailing: Search icon + configurable action (default: profile)
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Button {
                            navigationState.showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(AppTypography.inter(size: 14))
                                .foregroundColor(AppColors.textMuted)
                                .frame(width: 32, height: 32)
                                .background(AppColors.cardElevated)
                                .clipShape(Circle())
                        }
                        trailing
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                IntelligenceStrip()
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply the shared app toolbar with a balanced trailing spacer and optional help guide.
    func appToolbar(guide: FeatureGuide? = nil) -> some View {
        modifier(AppToolbarModifier(guide: guide, trailing: DefaultTrailingButton()))
    }

    /// Apply the shared app toolbar with custom trailing content and optional help guide.
    func appToolbar<Trailing: View>(guide: FeatureGuide? = nil, @ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(AppToolbarModifier(guide: guide, trailing: trailing()))
    }
}

// MARK: - Default Trailing Button (Profile)

private struct DefaultTrailingButton: View {
    @EnvironmentObject var navigationState: AppNavigationState

    var body: some View {
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
