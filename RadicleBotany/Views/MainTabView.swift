import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .botanize
    @State private var previousTabIndex: Int = 1  // Botanize (centre) is default
    @State private var navigationResetID = UUID()
    @EnvironmentObject private var navigationState: AppNavigationState
    @EnvironmentObject private var themeManager: ThemeManager

    enum Tab: String, CaseIterable {
        case journal, botanize, learn

        var tabIndex: Int {
            switch self {
            case .journal:  return 0
            case .botanize: return 1
            case .learn:    return 2
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Current tab content — simple opacity for performance
            // (spring + asymmetric move caused layout thrashing with large grids)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            customTabBar
        }
        .background(AppColors.appBackground)
        .onChange(of: selectedTab) { oldTab, _ in
            previousTabIndex = oldTab.tabIndex
        }
        .sheet(isPresented: $navigationState.showProfile) {
            NavigationStack {
                ProfileView()
            }
        }
        .sheet(isPresented: $navigationState.showSearch) {
            NavigationStack {
                SearchView()
            }
        }
        .sheet(isPresented: $navigationState.showChatbot) {
            NavigationStack {
                ChatView(context: navigationState.chatbotContext)
            }
        }
        .overlay {
            NotificationBannerOverlay()
        }
        .withAgenticGuidance()
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .journal:
            NavigationStack {
                JournalView()
                    .appToolbar(guide: .journal)
                    .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
                    .navigationDestination(for: Family.self) { FamilyDetailView(family: $0) }
                    .navigationDestination(for: BotanyTerm.self) { TermDetailView(term: $0) }
            }
            .id(navigationResetID)
        case .botanize:
            NavigationStack {
                BotanizeView()
                    .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
                    .navigationDestination(for: Family.self) { FamilyDetailView(family: $0) }
                    .navigationDestination(for: BotanyTerm.self) { TermDetailView(term: $0) }
            }
            .id(navigationResetID)
        case .learn:
            NavigationStack {
                LearnView()
                    .appToolbar(guide: .learn)
                    .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
                    .navigationDestination(for: Family.self) { FamilyDetailView(family: $0) }
                    .navigationDestination(for: BotanyTerm.self) { TermDetailView(term: $0) }
            }
            .id(navigationResetID)
        }
    }

    // MARK: - Transition Helpers

    private var tabMovedRight: Bool {
        selectedTab.tabIndex > previousTabIndex
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(icon: "book.closed.fill", label: "Journal", tab: .journal)

            // Centre — Botanize (elevated)
            centerBotanizeButton

            tabButton(icon: "books.vertical.fill", label: "Learn", tab: .learn)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, safeAreaBottomPadding + 4)
        .background(tabBarBackground)
    }

    // MARK: - Centre Botanize Button

    private var centerBotanizeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if selectedTab == .botanize {
                navigationResetID = UUID()
            } else {
                selectedTab = .botanize
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(AppColors.primaryAmber.opacity(0.15))
                        .frame(width: 60, height: 60)

                    // Main circle
                    Circle()
                        .fill(AppColors.primaryAmber)
                        .frame(width: 48, height: 48)
                        .shadow(color: AppColors.primaryAmber.opacity(0.35), radius: 10, y: 4)

                    // Icon — leaf with magnifying glass overlay
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.onAccent)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppColors.onAccent)
                                .offset(x: 4, y: -2)
                        }
                }

                Text("Botanize")
                    .font(AppTypography.navLabel)
                    .foregroundStyle(selectedTab == .botanize ? AppColors.primaryAmber : AppColors.textMuted)
            }
            .offset(y: -14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Botanize")
        .accessibilityAddTraits(selectedTab == .botanize ? .isSelected : [])
    }

    // MARK: - Side Tab Button

    private func tabButton(icon: String, label: String, tab: Tab) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if selectedTab == tab {
                navigationResetID = UUID()
            } else {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(selectedTab == tab ? AppColors.primaryAmber : AppColors.textMuted)
                Text(label)
                    .font(AppTypography.navLabel)
                    .foregroundStyle(selectedTab == tab ? AppColors.primaryAmber : AppColors.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }

    // MARK: - Tab Bar Background

    private var tabBarBackground: some View {
        Rectangle()
            .fill(AppColors.cardBackground)
            .overlay(
                Rectangle()
                    .fill(AppColors.borderSubtle)
                    .frame(height: 0.5),
                alignment: .top
            )
            .ignoresSafeArea(edges: .bottom)
    }

    private var safeAreaBottomPadding: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}
