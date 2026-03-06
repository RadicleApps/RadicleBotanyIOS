import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared

    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    @AppStorage("notionToken") private var notionToken = ""
    @AppStorage("notionPageID") private var notionPageID = ""

    @ObservedObject private var apiKeyManager = APIKeyManager.shared

    @State private var showClearDataAlert = false
    @State private var isRestoringPurchases = false
    @State private var notionConnectionStatus: String? = nil
    @State private var isTestingNotion = false
    @State private var showShareSheet = false
    @State private var claudeKeyInput = ""
    @State private var openAIKeyInput = ""
    @State private var isSavingClaudeKey = false
    @State private var isSavingOpenAIKey = false
    @State private var claudeKeyStatus: String? = nil
    @State private var openAIKeyStatus: String? = nil
    @State private var showClaudeConfig = false
    @State private var showOpenAIConfig = false
    @State private var showNotionConfig = false

    var scrollToNotion: Bool = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.sectionMarginBottom) {

                        // IDENTITY
                        identitySection

                        // INTEGRATIONS
                        integrationsSection

                        // BACKENDS
                        backendsSection

                        // SYSTEM
                        systemSection

                        // LEGAL & ABOUT
                        legalSection

                        // Footer
                        footerSection
                    }
                    .padding(.top, AppSpacing.screenPadding)
                }
            }
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.inline)
            .featureGuide(.dashboard)
            .onAppear {
                if scrollToNotion {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo("notionSection", anchor: .top)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [
                "Check out RadicleBotany — a botanical field guide and plant identifier. https://apps.apple.com/app/radiclebotany/id6759073523"
            ])
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showClaudeConfig) {
            claudeConfigSheet
        }
        .sheet(isPresented: $showOpenAIConfig) {
            openAIConfigSheet
        }
        .sheet(isPresented: $showNotionConfig) {
            notionConfigSheet
        }
        .alert("Clear Local Data", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Data", role: .destructive) {
                clearLocalData()
            }
        } message: {
            Text("This will permanently delete all local observations, achievements, and cached data. This action cannot be undone.")
        }
    }

    // MARK: - Identity Section

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("IDENTITY")
                .intelligenceHeader()
                .padding(.horizontal, AppSpacing.screenPadding)

            SectionCard(title: "Plan") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Plan")
                                .font(AppTypography.fieldLabel)
                                .foregroundColor(AppColors.textMuted)
                            Text(storeManager.userTier.displayName)
                                .font(AppTypography.fieldValue)
                                .foregroundColor(AppColors.textPrimary)
                        }

                        Spacer()

                        CategoryPill(
                            text: storeManager.userTier.displayName,
                            color: tierColor(for: storeManager.userTier)
                        )
                    }

                    Divider().background(AppColors.border)

                    HStack(spacing: 16) {
                        Button {
                            Task {
                                isRestoringPurchases = true
                                await storeManager.restorePurchases()
                                isRestoringPurchases = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if isRestoringPurchases {
                                    ProgressView()
                                        .tint(AppColors.primaryAmber)
                                        .scaleEffect(0.7)
                                }
                                Text("Restore Purchases")
                                    .font(AppTypography.buttonText)
                                    .foregroundColor(AppColors.primaryAmber)
                            }
                        }
                        .disabled(isRestoringPurchases)

                        Spacer()

                        if storeManager.userTier == .annual || storeManager.userTier == .path {
                            Button {
                                openSubscriptionManagement()
                            } label: {
                                Text("Manage")
                                    .font(AppTypography.buttonText)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    // MARK: - Integrations Section

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INTEGRATIONS")
                .intelligenceHeader()
                .padding(.horizontal, AppSpacing.screenPadding)

            VStack(spacing: 2) {
                // Notion card
                integrationCard(
                    icon: "doc.text.fill",
                    iconColor: AppColors.primaryAmber,
                    name: "Notion",
                    description: "Export journal notes and\nobservations to Notion",
                    isConfigured: !notionToken.isEmpty,
                    onConfigure: { showNotionConfig = true },
                    onRemove: {
                        notionToken = ""
                        notionPageID = ""
                        notionConnectionStatus = nil
                    }
                )

                // iCloud Sync card
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "icloud.fill")
                            .font(AppTypography.inter(size: 18))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("iCloud Sync")
                                .font(AppTypography.sectionHeader)
                                .foregroundStyle(AppColors.textPrimary)

                            if iCloudSyncEnabled && storeManager.userTier != .free {
                                Circle()
                                    .fill(AppColors.success)
                                    .frame(width: 7, height: 7)
                            }
                        }

                        Text("Sync observations across\nyour Apple devices")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    if storeManager.userTier != .free {
                        Toggle("", isOn: $iCloudSyncEnabled)
                            .labelsHidden()
                            .tint(AppColors.primaryAmber)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(AppTypography.inter(size: 10))
                            Text("Upgrade")
                                .font(AppTypography.tagText)
                        }
                        .foregroundColor(AppColors.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.cardElevated)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .padding(.horizontal, AppSpacing.screenPadding)
            .id("notionSection")

            // Explainer text
            Text("Connect external services to extend your botanical workflow. Export observations, sync data, and more.")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted.opacity(0.7))
                .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    // MARK: - Integration Card Component

    private func integrationCard(
        icon: String,
        iconColor: Color,
        name: String,
        description: String,
        isConfigured: Bool,
        onConfigure: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(AppTypography.inter(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    if isConfigured {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(description)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if isConfigured {
                Menu {
                    Button {
                        onConfigure()
                    } label: {
                        Label("Edit Configuration", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(AppTypography.inter(size: 20))
                        .foregroundStyle(AppColors.textMuted)
                }
            } else {
                Button {
                    onConfigure()
                } label: {
                    Text("Connect")
                        .font(AppTypography.buttonText)
                        .foregroundStyle(AppColors.primaryAmber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppColors.primaryAmber.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.cardBackground)
    }

    // MARK: - Backends Section

    private var backendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BACKENDS")
                .intelligenceHeader()
                .padding(.horizontal, AppSpacing.screenPadding)

            VStack(spacing: 2) {
                // Claude backend card
                backendCard(
                    icon: "brain.head.profile",
                    iconColor: AppColors.brandPurple,
                    name: "Claude",
                    description: "Anthropic's Claude API\nfor enhanced responses",
                    isConfigured: apiKeyManager.claudeKeyConfigured,
                    onConfigure: { showClaudeConfig = true },
                    onRemove: {
                        apiKeyManager.deleteClaudeKey()
                        claudeKeyStatus = nil
                        ChatbotService.shared.updateCapabilityMode()
                    }
                )

                // ChatGPT backend card
                backendCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: AppColors.success,
                    name: "ChatGPT",
                    description: "OpenAI's ChatGPT API for\ncontextual responses",
                    isConfigured: apiKeyManager.openAIKeyConfigured,
                    onConfigure: { showOpenAIConfig = true },
                    onRemove: {
                        apiKeyManager.deleteOpenAIKey()
                        openAIKeyStatus = nil
                        ChatbotService.shared.updateCapabilityMode()
                    }
                )

                // OpenClaw — Coming Soon
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(AppColors.cardElevated)
                            .frame(width: 48, height: 48)

                        Image(systemName: "terminal.fill")
                            .font(AppTypography.inter(size: 18))
                            .foregroundStyle(AppColors.textMuted.opacity(0.5))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Ollama")
                                .font(AppTypography.sectionHeader)
                                .foregroundStyle(AppColors.textMuted)

                            Text("COMING SOON")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.cardElevated)
                                .clipShape(Capsule())
                        }

                        Text("Self-hosted local models")
                            .font(AppTypography.tagText)
                            .foregroundStyle(AppColors.textMuted.opacity(0.5))
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .padding(.horizontal, AppSpacing.screenPadding)

            // Rate limit info for owner backend
            if IntelligenceBackendService.shared.isOwnerBackendActive {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(AppTypography.inter(size: 11))
                        .foregroundColor(AppColors.primaryAmber)

                    let remaining = RateLimitManager.shared.remainingQueries(tier: storeManager.userTier)
                    let limit = RateLimitManager.shared.dailyLimit(for: storeManager.userTier)
                    Text("Enhanced backend active — \(remaining)/\(limit) queries today")
                        .font(AppTypography.tagText)
                        .foregroundColor(AppColors.textMuted)
                }
                .padding(.horizontal, AppSpacing.screenPadding)
            }

            // Explainer text
            Text("Configure your API keys to enable enhanced chatbot responses. Keys are stored securely in your device's Keychain.")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted.opacity(0.7))
                .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    // MARK: - Backend Card Component

    private func backendCard(
        icon: String,
        iconColor: Color,
        name: String,
        description: String,
        isConfigured: Bool,
        onConfigure: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(AppTypography.inter(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary)

                    if isConfigured {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(description)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if isConfigured {
                Menu {
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove Key", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(AppTypography.inter(size: 20))
                        .foregroundStyle(AppColors.textMuted)
                }
            } else {
                Button {
                    onConfigure()
                } label: {
                    Text("Configure")
                        .font(AppTypography.buttonText)
                        .foregroundStyle(AppColors.primaryAmber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppColors.primaryAmber.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.primaryAmber.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppColors.cardBackground)
    }

    // MARK: - Claude Config Sheet

    private var claudeConfigSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header illustration
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(AppColors.brandPurple.opacity(0.1))
                                    .frame(width: 80, height: 80)

                                Image(systemName: "brain.head.profile")
                                    .font(AppTypography.inter(size: 32))
                                    .foregroundStyle(AppColors.brandPurple)
                            }
                            Spacer()
                        }

                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connect Claude")
                                .font(AppTypography.inter(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Add your Anthropic API key to enable Claude-powered botanical responses in the chatbot.")
                                .font(AppTypography.bodyText)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineSpacing(3)
                        }

                        // Steps
                        VStack(alignment: .leading, spacing: 14) {
                            configStep(number: 1, text: "Visit console.anthropic.com")
                            configStep(number: 2, text: "Create an API key under Settings → API Keys")
                            configStep(number: 3, text: "Paste the key below and tap Save")
                        }

                        // Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API KEY")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted)
                                .kerning(1.5)

                            SecureField("sk-ant-api03-...", text: $claudeKeyInput)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(AppColors.border, lineWidth: 0.5)
                                )
                        }

                        // Status
                        if let status = claudeKeyStatus {
                            HStack(spacing: 6) {
                                Image(systemName: status.contains("\u{2713}") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(status.contains("\u{2713}") ? AppColors.success : AppColors.error)
                                Text(status)
                                    .font(AppTypography.tagText)
                                    .foregroundStyle(status.contains("\u{2713}") ? AppColors.success : AppColors.error)
                            }
                        }

                        // Save button
                        Button {
                            saveClaudeKey()
                        } label: {
                            HStack(spacing: 8) {
                                if isSavingClaudeKey {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text("Save & Test Connection")
                                    .font(AppTypography.sectionHeader)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(color: AppColors.brandPurple))
                        .disabled(claudeKeyInput.isEmpty || isSavingClaudeKey)

                        // Security note
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(AppTypography.inter(size: 11))
                            Text("Keys are stored in your device's secure Keychain and never leave your device.")
                                .font(AppTypography.tagText)
                        }
                        .foregroundStyle(AppColors.textMuted.opacity(0.6))

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Claude Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showClaudeConfig = false
                    }
                    .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - OpenAI Config Sheet

    private var openAIConfigSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header illustration
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(AppColors.success.opacity(0.1))
                                    .frame(width: 80, height: 80)

                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(AppTypography.inter(size: 32))
                                    .foregroundStyle(AppColors.success)
                            }
                            Spacer()
                        }

                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connect ChatGPT")
                                .font(AppTypography.inter(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Add your OpenAI API key to enable ChatGPT-powered botanical responses in the chatbot.")
                                .font(AppTypography.bodyText)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineSpacing(3)
                        }

                        // Steps
                        VStack(alignment: .leading, spacing: 14) {
                            configStep(number: 1, text: "Visit platform.openai.com")
                            configStep(number: 2, text: "Create an API key under API Keys")
                            configStep(number: 3, text: "Paste the key below and tap Save")
                        }

                        // Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API KEY")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted)
                                .kerning(1.5)

                            SecureField("sk-proj-...", text: $openAIKeyInput)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(AppColors.border, lineWidth: 0.5)
                                )
                        }

                        // Status
                        if let status = openAIKeyStatus {
                            HStack(spacing: 6) {
                                Image(systemName: status.contains("\u{2713}") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(status.contains("\u{2713}") ? AppColors.success : AppColors.error)
                                Text(status)
                                    .font(AppTypography.tagText)
                                    .foregroundStyle(status.contains("\u{2713}") ? AppColors.success : AppColors.error)
                            }
                        }

                        // Save button
                        Button {
                            saveOpenAIKey()
                        } label: {
                            HStack(spacing: 8) {
                                if isSavingOpenAIKey {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text("Save & Test Connection")
                                    .font(AppTypography.sectionHeader)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(color: AppColors.success))
                        .disabled(openAIKeyInput.isEmpty || isSavingOpenAIKey)

                        // Security note
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(AppTypography.inter(size: 11))
                            Text("Keys are stored in your device's secure Keychain and never leave your device.")
                                .font(AppTypography.tagText)
                        }
                        .foregroundStyle(AppColors.textMuted.opacity(0.6))

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("ChatGPT Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showOpenAIConfig = false
                    }
                    .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Notion Config Sheet

    private var notionConfigSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header illustration
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(AppColors.primaryAmber.opacity(0.1))
                                    .frame(width: 80, height: 80)

                                Image(systemName: "doc.text.fill")
                                    .font(AppTypography.inter(size: 32))
                                    .foregroundStyle(AppColors.primaryAmber)
                            }
                            Spacer()
                        }

                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connect Notion")
                                .font(AppTypography.inter(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)

                            Text("Export your journal notes and plant observations directly to a Notion workspace.")
                                .font(AppTypography.bodyText)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineSpacing(3)
                        }

                        // Steps
                        VStack(alignment: .leading, spacing: 14) {
                            configStep(number: 1, text: "Visit notion.so/my-integrations")
                            configStep(number: 2, text: "Create a new integration and copy the token")
                            configStep(number: 3, text: "Share a Notion page with your integration")
                            configStep(number: 4, text: "Copy the page ID from the page URL")
                            configStep(number: 5, text: "Paste both below and tap Save")
                        }

                        // Token input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("INTEGRATION TOKEN")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted)
                                .kerning(1.5)

                            SecureField("ntn_...", text: $notionToken)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(AppColors.border, lineWidth: 0.5)
                                )
                        }

                        // Page ID input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PAGE ID")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundStyle(AppColors.textMuted)
                                .kerning(1.5)

                            TextField("abc123def456...", text: $notionPageID)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(14)
                                .background(AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(AppColors.border, lineWidth: 0.5)
                                )

                            Text("The 32-character ID at the end of your Notion page URL")
                                .font(AppTypography.dataMicro)
                                .foregroundStyle(AppColors.textMuted.opacity(0.6))
                        }

                        // Status
                        if let status = notionConnectionStatus {
                            HStack(spacing: 6) {
                                Image(systemName: status.contains("\u{2713}") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(status.contains("\u{2713}") ? AppColors.success : AppColors.error)
                                Text(status)
                                    .font(AppTypography.tagText)
                                    .foregroundStyle(status.contains("\u{2713}") ? AppColors.success : AppColors.error)
                            }
                        }

                        // Save & Test button
                        Button {
                            testNotionConnection()
                        } label: {
                            HStack(spacing: 8) {
                                if isTestingNotion {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text("Save & Test Connection")
                                    .font(AppTypography.sectionHeader)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(color: AppColors.primaryAmber))
                        .disabled(notionToken.isEmpty || isTestingNotion)

                        // Help link
                        Link(destination: URL(string: "https://www.notion.so/my-integrations")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle")
                                    .font(AppTypography.inter(size: 12))
                                Text("Notion Integration Docs")
                                    .font(AppTypography.tagText)
                                Image(systemName: "arrow.up.right")
                                    .font(AppTypography.inter(size: 9))
                            }
                            .foregroundStyle(AppColors.textMuted.opacity(0.7))
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, AppSpacing.screenPadding)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Notion Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showNotionConfig = false
                    }
                    .foregroundStyle(AppColors.primaryAmber)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Config Step Component

    private func configStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.primaryAmber)
                .frame(width: 24, height: 24)
                .background(AppColors.primaryAmber.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, 2)
        }
    }

    // MARK: - System Section

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SYSTEM")
                .intelligenceHeader()
                .padding(.horizontal, AppSpacing.screenPadding)

            // Appearance
            SectionCard(title: "Appearance") {
                VStack(spacing: 12) {
                    ForEach(LightingMode.allCases) { mode in
                        lightingModeRow(mode: mode)

                        if mode != LightingMode.allCases.last {
                            Divider().background(AppColors.border)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // Notifications
            SectionCard(title: "Notifications") {
                HStack {
                    Text("Push Notifications")
                        .font(AppTypography.fieldValue)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(AppColors.primaryAmber)
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            // Data Management
            SectionCard(title: "Data") {
                Button {
                    showClearDataAlert = true
                } label: {
                    HStack {
                        Text("Clear Local Data")
                            .font(AppTypography.buttonText)
                            .foregroundColor(AppColors.error)
                        Spacer()
                        Image(systemName: "trash")
                            .font(AppTypography.inter(size: 13))
                            .foregroundColor(AppColors.error.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)

            #if DEBUG
            // Admin
            SectionCard(title: "Admin") {
                NavigationLink(destination: AdminPlantImagesView()) {
                    HStack {
                        Text("Plant Images Manager")
                            .font(AppTypography.fieldValue)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(AppTypography.inter(size: 12))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            #endif
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LEGAL & ABOUT")
                .intelligenceHeader()
                .padding(.horizontal, AppSpacing.screenPadding)

            SectionCard {
                VStack(spacing: 14) {
                    FieldRowHorizontal(label: "Version", value: appVersion)

                    Divider().background(AppColors.border)

                    Link(destination: URL(string: "https://radiclebotany.app/dl/f3f484")!) {
                        dashboardLinkRow("Terms of Service")
                    }

                    Divider().background(AppColors.border)

                    Link(destination: URL(string: "https://radiclebotany.app/dl/29abc7")!) {
                        dashboardLinkRow("Privacy Policy")
                    }

                    Divider().background(AppColors.border)

                    NavigationLink(destination: ResourcesView()) {
                        HStack {
                            Text("Resources")
                                .font(AppTypography.fieldValue)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AppTypography.inter(size: 12))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider().background(AppColors.border)

                    Button {
                        showShareSheet = true
                    } label: {
                        dashboardLinkRow("Share with Friends")
                    }

                    Divider().background(AppColors.border)

                    Link(destination: URL(string: "mailto:support@radiclebotany.app")!) {
                        dashboardLinkRow("Contact Support")
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("RadicleBotany v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(AppTypography.dataMicro)
                .foregroundColor(AppColors.textMuted)
            Text("\u{00A9} 2026 RadicleBotany. All rights reserved.")
                .font(AppTypography.fieldLabel)
                .foregroundColor(AppColors.textMuted)
        }
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Lighting Mode Row

    private func lightingModeRow(mode: LightingMode) -> some View {
        let isSelected = themeManager.lightingMode == mode
        let previewPalette = ThemeManager.previewPalette(mode)

        return Button {
            themeManager.setLighting(mode)
        } label: {
            HStack(spacing: 14) {
                // Swatch preview
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(previewPalette.cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .stroke(
                                isSelected ? AppColors.primaryAmber : AppColors.border,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .overlay(
                        Image(systemName: mode.icon)
                            .font(AppTypography.inter(size: 16))
                            .foregroundColor(previewPalette.textPrimary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(AppTypography.fieldValue)
                        .foregroundColor(AppColors.textPrimary)
                    Text(mode.subtitle)
                        .font(AppTypography.fieldLabel)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(AppTypography.inter(size: 20))
                    .foregroundColor(isSelected ? AppColors.primaryAmber : AppColors.border)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dashboard Link Row

    private func dashboardLinkRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.fieldValue)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(AppTypography.inter(size: 11))
                .foregroundColor(AppColors.textMuted)
        }
    }

    // MARK: - Helpers

    private func tierColor(for tier: UserTier) -> Color {
        switch tier {
        case .free: return AppColors.textMuted
        case .annual: return AppColors.primaryAmber
        case .path: return AppColors.primaryAmber
        }
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func testNotionConnection() {
        isTestingNotion = true
        notionConnectionStatus = nil
        Task {
            do {
                let name = try await NotionService.shared.testConnection(token: notionToken)
                await MainActor.run {
                    notionConnectionStatus = "\u{2713} \(name)"
                    isTestingNotion = false
                }
            } catch {
                await MainActor.run {
                    notionConnectionStatus = "\u{2717} Failed"
                    isTestingNotion = false
                }
            }
        }
    }

    private func clearLocalData() {
        do {
            try modelContext.delete(model: PlantObservation.self)
            try modelContext.delete(model: Achievement.self)
        } catch {
            print("[DashboardView] Failed to clear local data: \(error)")
        }
    }

    // MARK: - Intelligence Key Management

    private func saveClaudeKey() {
        isSavingClaudeKey = true
        claudeKeyStatus = nil
        Task {
            do {
                try await apiKeyManager.saveClaudeKey(claudeKeyInput)
                await MainActor.run {
                    claudeKeyInput = ""
                    claudeKeyStatus = "\u{2713} Connected"
                    isSavingClaudeKey = false
                    ChatbotService.shared.updateCapabilityMode()
                    showClaudeConfig = false
                }
            } catch {
                await MainActor.run {
                    claudeKeyStatus = "\u{2717} \(error.localizedDescription)"
                    isSavingClaudeKey = false
                }
            }
        }
    }

    private func saveOpenAIKey() {
        isSavingOpenAIKey = true
        openAIKeyStatus = nil
        Task {
            do {
                try await apiKeyManager.saveOpenAIKey(openAIKeyInput)
                await MainActor.run {
                    openAIKeyInput = ""
                    openAIKeyStatus = "\u{2713} Connected"
                    isSavingOpenAIKey = false
                    ChatbotService.shared.updateCapabilityMode()
                    showOpenAIConfig = false
                }
            } catch {
                await MainActor.run {
                    openAIKeyStatus = "\u{2717} \(error.localizedDescription)"
                    isSavingOpenAIKey = false
                }
            }
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
