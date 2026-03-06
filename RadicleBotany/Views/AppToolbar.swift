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
                // Leading: Optional help button
                ToolbarItem(placement: .topBarLeading) {
                    if let guide {
                        InfoButton(guide: guide, style: .toolbar)
                    }
                }

                // Center: Compact search capsule — short text prevents cramping
                ToolbarItem(placement: .principal) {
                    Button {
                        navigationState.showSearch = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "magnifyingglass")
                                .font(AppTypography.inter(size: 11, weight: .medium))
                            Text("Search...")
                                .font(AppTypography.inter(size: 13, weight: .regular))
                        }
                        .foregroundStyle(AppColors.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppColors.cardElevated)
                        .clipShape(Capsule())
                    }
                }

                // Trailing: Configurable (default spacer, or custom e.g. + button)
                ToolbarItem(placement: .topBarTrailing) {
                    trailing
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
