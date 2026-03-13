import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsQuery: [UserSettings]

    @State private var currentPage = 0
    @State private var purchaseInProgress = false
    @State private var showError = false

    // Personalization
    @State private var selectedExperience: BotanicalExperience? = nil
    @State private var selectedGoals: Set<BotanicalGoal> = []


    private let totalPages = 7

    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Main page content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    botanizePage.tag(1)
                    learnPage.tag(2)
                    collectPage.tag(3)
                    experiencePage.tag(4)
                    goalsPage.tag(5)
                    pricingPage.tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom navigation (dots + button) — not on pricing page
                if currentPage < totalPages - 1 {
                    bottomNavigation
                        .padding(.bottom, 40)
                }
            }

            // Skip button on pages 0-5
            if currentPage < totalPages - 1 {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation { currentPage = totalPages - 1 }
                        } label: {
                            Text("Skip")
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.textMuted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    Spacer()
                }
            }

            // Loading overlay for purchases
            if storeManager.isLoading || purchaseInProgress {
                purchaseLoadingOverlay
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                storeManager.errorMessage = nil
            }
        } message: {
            Text(storeManager.errorMessage ?? "An unknown error occurred.")
        }
        .onChange(of: storeManager.errorMessage) { _, newValue in
            showError = newValue != nil
        }
    }

    // MARK: - Bottom Navigation

    private var canAdvance: Bool {
        switch currentPage {
        case 4: return selectedExperience != nil
        case 5: return !selectedGoals.isEmpty
        default: return true
        }
    }

    private var nextButtonLabel: String {
        currentPage == 5 ? "Continue" : "Next"
    }

    private var bottomNavigation: some View {
        VStack(spacing: 20) {
            progressDots

            Button {
                withAnimation { currentPage += 1 }
            } label: {
                Text(nextButtonLabel)
            }
            .buttonStyle(PrimaryButtonStyle(color: currentPage >= 4 ? .orangePrimary : .purpleSecondary))
            .disabled(!canAdvance)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Custom Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<(totalPages - 1), id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? AppColors.primaryAmber : AppColors.textMuted.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("Actinomorphic (symmetry) color")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 220)
                .shadow(color: Color.black.opacity(0.2), radius: 16, y: 6)

            VStack(spacing: 8) {
                Text("RadicleBotany")
                    .font(.cormorant(size: 40, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("A Modern Botanical Field Guide")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Page 2: Botanize (Identify)

    private var botanizePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("FlowerParts")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 220)
                .shadow(color: Color.black.opacity(0.2), radius: 16, y: 6)

            VStack(spacing: 10) {
                Text("Observe & Identify Plants")
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Choose from illustrated botanical terms, use camera, or combine both methods to identify plants.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 16) {
                onboardingFeatureChip(icon: "eye.fill", text: "Observe", color: .orangePrimary)
                onboardingFeatureChip(icon: "camera.fill", text: "Capture", color: .greenSecondary)
                onboardingFeatureChip(icon: "sparkles", text: "Both", color: .purpleSecondary)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Page 3: Learn

    private var learnPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("LeafParts")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 220)
                .shadow(color: Color.black.opacity(0.2), radius: 16, y: 6)

            VStack(spacing: 10) {
                Text("Illustrated Botanical Terminology")
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Explore 2,330+ species, 190+ families, and 460+ terms with detailed morphological traits. Every species cross-links to plant family and related terminology.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 16) {
                onboardingFeatureChip(icon: "leaf.fill", text: "Species", color: .greenSecondary)
                onboardingFeatureChip(icon: "leaf.circle.fill", text: "Families", color: .orangePrimary)
                onboardingFeatureChip(icon: "text.book.closed.fill", text: "Terms", color: .purpleSecondary)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Page 4: Collect

    private var collectPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("StemParts")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 220)
                .shadow(color: Color.black.opacity(0.2), radius: 16, y: 6)

            VStack(spacing: 10) {
                Text("Track Your Discoveries")
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Log every plant with photos, GPS location, and verified traits. Build collections, maintain your streak, and watch your expertise grow.")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 16) {
                onboardingFeatureChip(icon: "camera.fill", text: "Observe", color: .orangePrimary)
                onboardingFeatureChip(icon: "folder.fill", text: "Collect", color: .purpleSecondary)
                onboardingFeatureChip(icon: "flame.fill", text: "Streak", color: .orangeLight)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Page 5: Experience

    private var experiencePage: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            VStack(spacing: 8) {
                Text("Your Botanical Background")
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Helps us tailor the app for you")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(BotanicalExperience.allCases, id: \.self) { option in
                    experienceOptionRow(option)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func experienceOptionRow(_ option: BotanicalExperience) -> some View {
        let isSelected = selectedExperience == option
        return Button {
            selectedExperience = option
        } label: {
            HStack(spacing: 14) {
                Image(systemName: option.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.primaryAmber)
                    .frame(width: 36, height: 36)
                    .background(AppColors.primaryAmber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.rawValue.capitalized)
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(option.label)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.inter(size: 18))
                        .foregroundStyle(AppColors.primaryAmber)
                }
            }
            .padding(16)
            .background(isSelected ? AppColors.primaryAmber.opacity(0.08) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(
                        isSelected ? AppColors.primaryAmber.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 6: Goals

    private var goalsPage: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            VStack(spacing: 8) {
                Text("Your Goals")
                    .font(AppTypography.headerTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Select all that apply")
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(BotanicalGoal.allCases, id: \.self) { goal in
                    goalOptionRow(goal)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func goalOptionRow(_ goal: BotanicalGoal) -> some View {
        let isSelected = selectedGoals.contains(goal)
        return Button {
            if isSelected {
                selectedGoals.remove(goal)
            } else {
                selectedGoals.insert(goal)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: goal.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.primaryAmber)
                    .frame(width: 36, height: 36)
                    .background(AppColors.primaryAmber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(goal.label)
                    .font(AppTypography.bodyText)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppTypography.inter(size: 18))
                        .foregroundStyle(AppColors.primaryAmber)
                }
            }
            .padding(16)
            .background(isSelected ? AppColors.primaryAmber.opacity(0.08) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(
                        isSelected ? AppColors.primaryAmber.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 7: Pricing

    private var pricingPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 12)

                // Personalized header
                VStack(spacing: 8) {
                    Text(personalizedHeadline)
                        .font(AppTypography.headerTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("7 days free — full access, no limits")
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                }

                // RadicleBotany Card
                pricingAnnualCardContent

                // Primary CTA
                Button {
                    Task { await purchaseSelectedTier() }
                } label: {
                    Text("Start 7-Day Free Trial")
                }
                .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
                .disabled(storeManager.isLoading || purchaseInProgress)

                // Sub-price label
                let selectedPrice = storeManager.annualProduct?.displayPrice ?? "$33.99"
                Text("Then \(selectedPrice)/year · cancel anytime")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)

                // Footer
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await storeManager.restorePurchases()
                            if storeManager.userTier != .free {
                                completeOnboarding()
                            }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }
                    .disabled(storeManager.isLoading || purchaseInProgress)

                    HStack(spacing: 20) {
                        Link("Terms of Use", destination: URL(string: "https://radiclebotany.app/dl/f3f484")!)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)

                        Link("Privacy Policy", destination: URL(string: "https://radiclebotany.app/dl/29abc7")!)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textMuted)
                    }

                    Text("RadicleBotany subscription: \(selectedPrice)/year after 7-day free trial. Payment charged to Apple ID at confirmation. Auto-renews yearly unless cancelled at least 24 hours before period end. Manage in Apple ID Account Settings.")
                        .font(AppTypography.inter(size: 10))
                        .foregroundStyle(AppColors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 4)

                Spacer()
                    .frame(height: 20)
            }
            .padding(.horizontal, 24)
        }
    }

    private var pricingAnnualCardContent: some View {
        VStack(spacing: 16) {
            HStack {
                Text("RADICLEBOTANY")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.primaryAmber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.primaryAmber.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(storeManager.annualProduct?.displayPrice ?? "$33.99")
                        .font(AppTypography.headerTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("7-day free trial")
                        .font(AppTypography.tagText)
                        .foregroundStyle(AppColors.primaryAmber)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                pricingFeatureRow("All species & families", color: .orangePrimary)
                pricingFeatureRow("Botanical terms", color: .orangePrimary)
                pricingFeatureRow("Unlimited Observe mode", color: .orangePrimary)
                pricingFeatureRow("Journal & Collections", color: .orangePrimary)
                pricingFeatureRow("Flashcards & study streaks", color: .orangePrimary)
                pricingFeatureRow("Photo Identification", color: .orangePrimary)
                pricingFeatureRow("Both mode", color: .orangePrimary)
                pricingFeatureRow("Plant Assistant", color: .orangePrimary)
                pricingFeatureRow("iCloud sync across devices", color: .orangePrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.primaryAmber.opacity(0.6), lineWidth: 2)
        )
    }

    // MARK: - Personalized Headline

    private var personalizedHeadline: String {
        switch selectedExperience {
        case .novice:       return "Start identifying plants."
        case .enthusiast:   return "Expand your plant knowledge."
        case .student:      return "Everything a botany student needs."
        case .professional: return "Built for field botanists."
        case nil:           return "Access the full database."
        }
    }

    // MARK: - Pricing Feature Row

    private func pricingFeatureRow(_ text: String, color: Color = .secondary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(color)

            Text(text)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Onboarding Feature Row (non-interactive, informational only)

    private func onboardingFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textMuted)
                .frame(width: 18)
            Text(text)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func onboardingFeatureChip(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 18))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Loading Overlay

    private var purchaseLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppColors.primaryAmber)
                    .scaleEffect(1.2)

                Text("Processing...")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(32)
            .background(AppColors.cardElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.badge))
        }
    }

    // MARK: - Purchase Action

    private func purchaseSelectedTier() async {
        guard let product = storeManager.annualProduct else {
            await storeManager.fetchProducts()
            return
        }
        purchaseInProgress = true
        let success = await storeManager.purchase(product)
        purchaseInProgress = false
        if success { completeOnboarding() }
    }

    // MARK: - Complete Onboarding

    private func completeOnboarding() {
        // Save personalization to UserSettings if available
        if let settings = settingsQuery.first {
            settings.botanicalExperience = selectedExperience?.rawValue
            if !selectedGoals.isEmpty,
               let data = try? JSONEncoder().encode(selectedGoals.map(\.rawValue)),
               let str = String(data: data, encoding: .utf8) {
                settings.botanicalGoals = str
            }
        }
        hasCompletedOnboarding = true
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(StoreManager(preview: true))
        .preferredColorScheme(.dark)
}
