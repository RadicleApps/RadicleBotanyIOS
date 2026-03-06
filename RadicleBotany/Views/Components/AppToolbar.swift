import SwiftUI

// MARK: - App Toolbar Modifier

/// Applies the shared top toolbar (chat + search + trailing action)
/// to any NavigationStack. Compact layout prevents cramping.
struct AppToolbarModifier<Trailing: View>: ViewModifier {
    @EnvironmentObject var navigationState: AppNavigationState
    let trailing: Trailing

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Leading: Spacer (chat button hidden for now)
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 0, height: 0)
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
    /// Apply the shared app toolbar with a balanced trailing spacer.
    func appToolbar() -> some View {
        modifier(AppToolbarModifier(trailing: DefaultTrailingButton()))
    }

    /// Apply the shared app toolbar with custom trailing content.
    func appToolbar<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(AppToolbarModifier(trailing: trailing()))
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
