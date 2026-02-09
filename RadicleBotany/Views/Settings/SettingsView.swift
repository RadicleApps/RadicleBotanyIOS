import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appTheme") private var appTheme: AppTheme = .dark
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    @State private var showClearDataAlert = false
    @State private var isRestoringPurchases = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                accountSection
                preferencesSection
                dataSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear Local Data", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Data", role: .destructive) {
                clearLocalData()
            }
        } message: {
            Text("This will permanently delete all local observations, achievements, and cached data. This action cannot be undone.")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ACCOUNT")

            VStack(spacing: 0) {
                // Current Plan
                HStack {
                    settingsRowIcon("creditcard.fill", color: .orangePrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Plan")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)
                        Text(storeManager.userTier.displayName)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    CategoryPill(
                        text: storeManager.userTier.displayName,
                        color: tierColor(for: storeManager.userTier)
                    )
                }
                .padding(14)

                settingsDivider

                // Manage Subscription (Pro only)
                if storeManager.userTier == .pro {
                    Button {
                        openSubscriptionManagement()
                    } label: {
                        HStack {
                            settingsRowIcon("arrow.triangle.2.circlepath", color: .greenSecondary)

                            Text("Manage Subscription")
                                .font(AppFont.body())
                                .foregroundStyle(Color.textPrimary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textMuted)
                        }
                        .padding(14)
                    }
                    .buttonStyle(.plain)

                    settingsDivider
                }

                // Restore Purchases
                Button {
                    Task {
                        isRestoringPurchases = true
                        await storeManager.restorePurchases()
                        isRestoringPurchases = false
                    }
                } label: {
                    HStack {
                        settingsRowIcon("arrow.clockwise", color: .purpleSecondary)

                        Text("Restore Purchases")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        if isRestoringPurchases {
                            ProgressView()
                                .tint(Color.textMuted)
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
                .disabled(isRestoringPurchases)
            }
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PREFERENCES")

            VStack(spacing: 0) {
                // Theme Picker
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        settingsRowIcon("paintbrush.fill", color: .purpleSecondary)

                        Text("Theme")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)

                        Spacer()
                    }

                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(14)

                settingsDivider

                // Notifications Toggle
                HStack {
                    settingsRowIcon("bell.fill", color: .orangeLight)

                    Text("Notifications")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(Color.orangePrimary)
                }
                .padding(14)
            }
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DATA")

            VStack(spacing: 0) {
                // iCloud Sync
                HStack {
                    settingsRowIcon("icloud.fill", color: .greenSecondary)

                    Text("iCloud Sync")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    if storeManager.userTier == .pro {
                        Toggle("", isOn: $iCloudSyncEnabled)
                            .labelsHidden()
                            .tint(Color.greenSecondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text("Pro")
                                .font(AppFont.caption())
                        }
                        .foregroundStyle(Color.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.surfaceElevated)
                        .clipShape(Capsule())
                    }
                }
                .padding(14)

                settingsDivider

                // Export Data
                Button {
                    // Placeholder for data export
                } label: {
                    HStack {
                        settingsRowIcon("square.and.arrow.up.fill", color: .purpleSecondary)

                        Text("Export Data")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                settingsDivider

                // Clear Local Data
                Button {
                    showClearDataAlert = true
                } label: {
                    HStack {
                        settingsRowIcon("trash.fill", color: .errorRed)

                        Text("Clear Local Data")
                            .font(AppFont.body())
                            .foregroundStyle(Color.errorRed)

                        Spacer()
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ABOUT")

            VStack(spacing: 0) {
                // Version
                HStack {
                    settingsRowIcon("info.circle.fill", color: .textSecondary)

                    Text("Version")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Text(appVersion)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                }
                .padding(14)

                settingsDivider

                // Terms of Service
                Link(destination: URL(string: "https://radiclebotany.com/terms")!) {
                    HStack {
                        settingsRowIcon("doc.text.fill", color: .textSecondary)

                        Text("Terms of Service")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(14)
                }

                settingsDivider

                // Privacy Policy
                Link(destination: URL(string: "https://radiclebotany.com/privacy")!) {
                    HStack {
                        settingsRowIcon("hand.raised.fill", color: .textSecondary)

                        Text("Privacy Policy")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(14)
                }

                settingsDivider

                // Contact Support
                Link(destination: URL(string: "mailto:support@radiclebotany.com")!) {
                    HStack {
                        settingsRowIcon("envelope.fill", color: .textSecondary)

                        Text("Contact Support")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textMuted)
                    }
                    .padding(14)
                }
            }
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppFont.caption())
            .foregroundStyle(Color.textMuted)
    }

    private func settingsRowIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    private func tierColor(for tier: UserTier) -> Color {
        switch tier {
        case .free: return .textMuted
        case .lifetime: return .orangePrimary
        case .pro: return .greenSecondary
        }
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func clearLocalData() {
        do {
            try modelContext.delete(model: Observation.self)
            try modelContext.delete(model: Achievement.self)
        } catch {
            print("[SettingsView] Failed to clear local data: \(error)")
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(StoreManager())
            .modelContainer(for: [Observation.self, Achievement.self], inMemory: true)
    }
}
