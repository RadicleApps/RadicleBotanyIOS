import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var storeManager: StoreManager

    @State private var currentPage = 0

    private let totalPages = 5

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                botanizePage.tag(1)
                learnPage.tag(2)
                collectPage.tag(3)
                pricingPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Skip button on pages 0-3
            if currentPage < totalPages - 1 {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(AppFont.sectionHeader())
                                .foregroundStyle(Color.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orangePrimary.opacity(0.15))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.orangePrimary.opacity(0.08))
                    .frame(width: 180, height: 180)

                ZStack {
                    Circle()
                        .fill(Color.orangePrimary)
                        .frame(width: 100, height: 100)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 10) {
                Text("RadicleBotany")
                    .font(AppFont.title(32))
                    .foregroundStyle(Color.textPrimary)

                Text("Learn plants. Know nature.")
                    .font(AppFont.bodyLarge())
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Page 2: Botanize

    private var botanizePage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.greenSecondary.opacity(0.12))
                    .frame(width: 140, height: 140)

                ZStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.greenSecondary)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.greenLight)
                        .offset(x: 20, y: -18)
                }
            }

            VStack(spacing: 10) {
                Text("Three Ways to Identify")
                    .font(AppFont.title(24))
                    .foregroundStyle(Color.textPrimary)

                Text("Use Observe mode to learn morphological traits through guided questions. Use Capture mode for instant AI identification. Or combine Both for the best results.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
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

            ZStack {
                Circle()
                    .fill(Color.purpleSecondary.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "book.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.purpleSecondary)
            }

            VStack(spacing: 10) {
                Text("179 Species. 183 Families.")
                    .font(AppFont.title(24))
                    .foregroundStyle(Color.textPrimary)

                Text("Explore a curated botanical database with detailed morphological traits, cross-referenced families, and hundreds of botanical terms. Every species links to its family and relevant terminology.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: 16) {
                onboardingFeatureChip(icon: "leaf.fill", text: "Species", color: .greenSecondary)
                onboardingFeatureChip(icon: "tree.fill", text: "Families", color: .orangePrimary)
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

            ZStack {
                Circle()
                    .fill(Color.orangePrimary.opacity(0.12))
                    .frame(width: 140, height: 140)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.orangePrimary)
            }

            VStack(spacing: 10) {
                Text("Your Botanical Journal")
                    .font(AppFont.title(24))
                    .foregroundStyle(Color.textPrimary)

                Text("Log every plant you encounter with photos, location, and verified traits. Build collections, track your streak, and watch your botanical knowledge grow over time.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
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

    // MARK: - Page 5: Pricing

    private var pricingPage: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 20)

            Text("Choose Your Path")
                .font(AppFont.title(24))
                .foregroundStyle(Color.textPrimary)

            Text("Start free, go further when you're ready.")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)

            VStack(spacing: 12) {
                // Lifetime Tier Card
                pricingCard(
                    tier: "Lifetime",
                    price: storeManager.lifetimeProduct?.displayPrice ?? "$29.99",
                    subtitle: "One-time purchase",
                    features: [
                        "All 179 species & 183 families",
                        "Full botanical journal",
                        "Collections & achievements"
                    ],
                    accentColor: .orangePrimary,
                    isHighlighted: true
                )

                // Pro Tier Card
                pricingCard(
                    tier: "Pro",
                    price: storeManager.proMonthlyProduct?.displayPrice ?? "$2.99/mo",
                    subtitle: "or \(storeManager.proYearlyProduct?.displayPrice ?? "$19.99/yr")",
                    features: [
                        "Everything in Lifetime",
                        "AI-powered Capture mode",
                        "iCloud sync across devices"
                    ],
                    accentColor: .greenSecondary,
                    isHighlighted: false
                )
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    if let product = storeManager.lifetimeProduct {
                        Task {
                            let success = await storeManager.purchase(product)
                            if success { completeOnboarding() }
                        }
                    }
                } label: {
                    Text("Get Lifetime Access")
                }
                .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))

                Button {
                    if let product = storeManager.proMonthlyProduct {
                        Task {
                            let success = await storeManager.purchase(product)
                            if success { completeOnboarding() }
                        }
                    }
                } label: {
                    Text("Start Free Trial")
                }
                .buttonStyle(SecondaryButtonStyle(color: .greenSecondary))

                Button {
                    completeOnboarding()
                } label: {
                    Text("Continue Free")
                }
                .buttonStyle(GhostButtonStyle(color: .textSecondary))
            }
            .padding(.horizontal, 8)

            Spacer()
                .frame(height: 20)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Pricing Card

    private func pricingCard(
        tier: String,
        price: String,
        subtitle: String,
        features: [String],
        accentColor: Color,
        isHighlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tier)
                    .font(AppFont.sectionHeader(16))
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(AppFont.sectionHeader(16))
                        .foregroundStyle(accentColor)

                    Text(subtitle)
                        .font(AppFont.caption(10))
                        .foregroundStyle(Color.textMuted)
                }
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)

                    Text(feature)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHighlighted ? accentColor.opacity(0.5) : Color.borderSubtle,
                    lineWidth: isHighlighted ? 1.5 : 0.5
                )
        )
    }

    // MARK: - Onboarding Feature Chip

    private func onboardingFeatureChip(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(text)
                .font(AppFont.caption())
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
        .environmentObject(StoreManager())
}
