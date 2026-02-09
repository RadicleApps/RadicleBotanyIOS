import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .botanize
    @State private var showProfile = false
    @State private var showSearch = false

    enum Tab: String {
        case journey, botanize, learn
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .journey:
                    NavigationStack {
                        JourneyView()
                            .toolbar { headerToolbar }
                    }
                case .botanize:
                    NavigationStack {
                        BotanizeView()
                            .toolbar { headerToolbar }
                    }
                case .learn:
                    NavigationStack {
                        LearnView()
                            .toolbar { headerToolbar }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 80)

            customTabBar
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
        }
        .sheet(isPresented: $showSearch) {
            NavigationStack {
                SearchView()
            }
        }
    }

    // MARK: - Header Toolbar

    @ToolbarContentBuilder
    private var headerToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showProfile = true
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.textSecondary)
            }
        }

        ToolbarItem(placement: .principal) {
            Button {
                showSearch = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                    Text("Search plants, families, terms...")
                        .font(AppFont.caption())
                }
                .foregroundStyle(Color.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.surfaceElevated)
                .clipShape(Capsule())
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {} label: {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack {
            tabButton(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Journey", tab: .journey)

            Spacer()

            Button {
                selectedTab = .botanize
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color.orangePrimary)
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.orangePrimary.opacity(0.4), radius: 8, y: 2)
                        Image(systemName: "leaf.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 4, y: -2)
                            }
                    }
                    .offset(y: -10)

                    Text("Botanize")
                        .font(AppFont.caption(10))
                        .foregroundStyle(selectedTab == .botanize ? Color.orangePrimary : Color.textMuted)
                        .offset(y: -10)
                }
            }

            Spacer()

            tabButton(icon: "leaf.fill", label: "Learn", tab: .learn)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            Color.surface
                .overlay(
                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }

    private func tabButton(icon: String, label: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(selectedTab == tab ? Color.orangePrimary : Color.textMuted)
                Text(label)
                    .font(AppFont.caption(10))
                    .foregroundStyle(selectedTab == tab ? Color.orangePrimary : Color.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
