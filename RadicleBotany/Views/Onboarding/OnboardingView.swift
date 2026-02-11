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
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Progress dots + Skip overlay
            VStack {
                HStack {
                    progressDots

                    Spacer()

                    if currentPage < totalPages - 1 {
                        Button {
                            withAnimation { currentPage = totalPages - 1 }
                        } label: {
                            Text("Skip")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()
            }
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.orangePrimary : Color.borderSubtle)
                    .frame(width: index == currentPage ? 20 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Icon
            ZStack {
                Circle()
                    .fill(Color.orangePrimary.opacity(0.1))
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(Color.orangePrimary.opacity(0.06))
                    .frame(width: 220, height: 220)

                ZStack {
                    Circle()
                        .fill(Color.orangePrimary)
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.orangePrimary.opacity(0.3), radius: 20, y: 4)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                }
            }

            Spacer()
                .frame(height: 36)

            VStack(spacing: 12) {
                Text("RadicleBotany")
                    .font(AppFont.title(34))
                    .foregroundStyle(Color.textPrimary)

                Text("Identify, learn, and journal\nthe plants around you.")
                    .font(AppFont.bodyLarge())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
            }
            .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Page 2: Botanize (Flower Anatomy Image)

    private var botanizePage: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            // Botanical illustration
            onboardingImage("OnboardingFlower", fallbackIcon: "camera.macro", fallbackColor: .orangePrimary)

            Spacer()
                .frame(height: 28)

            VStack(spacing: 12) {
                Text("Identify Any Plant")
                    .font(AppFont.title(26))
                    .foregroundStyle(Color.textPrimary)

                Text("Use guided trait questions, AI-powered camera identification, or combine both for the most accurate results.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 24)

            HStack(spacing: 16) {
                onboardingFeatureChip(icon: "eye.fill", text: "Observe", color: .orangePrimary)
                onboardingFeatureChip(icon: "camera.fill", text: "Capture", color: .greenSecondary)
                onboardingFeatureChip(icon: "sparkles", text: "Both", color: .purpleSecondary)
            }

            Spacer()

            nextButton(page: 2)
                .padding(.bottom, 60)
        }
    }

    // MARK: - Page 3: Learn (Leaf Anatomy Image)

    private var learnPage: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            // Botanical illustration
            onboardingImage("OnboardingLeaf", fallbackIcon: "leaf.fill", fallbackColor: .greenSecondary)

            Spacer()
                .frame(height: 28)

            VStack(spacing: 12) {
                Text("Master Plant Morphology")
                    .font(AppFont.title(26))
                    .foregroundStyle(Color.textPrimary)

                Text("Explore 179 species, 183 families, and 464 botanical terms — all cross-referenced and richly detailed.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 24)

            HStack(spacing: 16) {
                onboardingFeatureChip(icon: "leaf.fill", text: "Species", color: .greenSecondary)
                onboardingFeatureChip(icon: "tree.fill", text: "Families", color: .orangePrimary)
                onboardingFeatureChip(icon: "text.book.closed.fill", text: "Terms", color: .purpleSecondary)
            }

            Spacer()

            nextButton(page: 3)
                .padding(.bottom, 60)
        }
    }

    // MARK: - Page 4: Journal (Fruit Types Image)

    private var collectPage: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            // Botanical illustration
            onboardingImage("OnboardingFruit", fallbackIcon: "book.closed.fill", fallbackColor: .purpleSecondary)

            Spacer()
                .frame(height: 28)

            VStack(spacing: 12) {
                Text("Build Your Field Journal")
                    .font(AppFont.title(26))
                    .foregroundStyle(Color.textPrimary)

                Text("Log every plant you encounter with photos, location, and verified traits. Track your streak and watch your knowledge grow.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 24)

            HStack(spacing: 16) {
                onboardingFeatureChip(icon: "camera.fill", text: "Photo", color: .orangePrimary)
                onboardingFeatureChip(icon: "mappin.circle.fill", text: "Location", color: .greenSecondary)
                onboardingFeatureChip(icon: "flame.fill", text: "Streaks", color: .orangeLight)
            }

            Spacer()

            nextButton(page: 4)
                .padding(.bottom, 60)
        }
    }

    // MARK: - Page 5: Pricing

    private var pricingPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer()
                    .frame(height: 48)

                // Stem illustration as accent
                Image("OnboardingStem")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .opacity(0.6)

                Text("Unlock Everything")
                    .font(AppFont.title(26))
                    .foregroundStyle(Color.textPrimary)

                Text("One price. Lifetime access. No subscriptions.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)

                VStack(spacing: 12) {
                    // Lifetime Tier Card (highlighted — best value)
                    pricingCard(
                        tier: "Lifetime",
                        price: storeManager.lifetimeProduct?.displayPrice ?? "$24.99",
                        subtitle: "Pay once, yours forever",
                        badge: "Best Value",
                        features: [
                            "All 179 species & 183 families",
                            "AI-powered Capture & Both modes",
                            "Full botanical journal & collections",
                            "All achievements & streaks"
                        ],
                        accentColor: .orangePrimary,
                        isHighlighted: true
                    )

                    // Pro Tier Card
                    pricingCard(
                        tier: "Pro",
                        price: storeManager.proYearlyProduct?.displayPrice ?? "$19.99/yr",
                        subtitle: proSubtitle,
                        badge: nil,
                        features: [
                            "Everything in Lifetime",
                            "iCloud sync across devices",
                            "Priority future updates"
                        ],
                        accentColor: .greenSecondary,
                        isHighlighted: false
                    )
                }
                .padding(.horizontal, 4)

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
                        if let product = storeManager.proYearlyProduct {
                            Task {
                                let success = await storeManager.purchase(product)
                                if success { completeOnboarding() }
                            }
                        }
                    } label: {
                        Text("Start Pro — Yearly")
                    }
                    .buttonStyle(SecondaryButtonStyle(color: .greenSecondary))

                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Continue with Free")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textMuted)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 4)

                // Value framing
                Text("Less than the cost of a single field guide.")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.textMuted)
                    .italic()
                    .padding(.top, 4)

                // Terms
                HStack(spacing: 16) {
                    Button("Restore Purchases") {
                        Task { await storeManager.restorePurchases() }
                    }
                    .font(AppFont.caption(10))
                    .foregroundStyle(Color.textMuted)

                    Text("·")
                        .foregroundStyle(Color.textMuted)

                    Button("Terms of Use") {}
                        .font(AppFont.caption(10))
                        .foregroundStyle(Color.textMuted)

                    Text("·")
                        .foregroundStyle(Color.textMuted)

                    Button("Privacy") {}
                        .font(AppFont.caption(10))
                        .foregroundStyle(Color.textMuted)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Pro Subtitle (Savings Framing)

    private var proSubtitle: String {
        let monthly = storeManager.proMonthlyProduct?.displayPrice ?? "$2.99/mo"
        return "or \(monthly) · Save 44% yearly"
    }

    // MARK: - Pricing Card

    private func pricingCard(
        tier: String,
        price: String,
        subtitle: String,
        badge: String?,
        features: [String],
        accentColor: Color,
        isHighlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(tier)
                            .font(AppFont.sectionHeader(16))
                            .foregroundStyle(Color.textPrimary)

                        if let badge = badge {
                            Text(badge)
                                .font(AppFont.caption(10))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(AppFont.caption(10))
                        .foregroundStyle(Color.textMuted)
                }

                Spacer()

                Text(price)
                    .font(AppFont.title(20))
                    .foregroundStyle(accentColor)
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)

                    Text(feature)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isHighlighted ? accentColor.opacity(0.6) : Color.borderSubtle,
                    lineWidth: isHighlighted ? 1.5 : 0.5
                )
        )
    }

    // MARK: - Onboarding Image

    private func onboardingImage(_ name: String, fallbackIcon: String, fallbackColor: Color) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280, maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
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

    // MARK: - Next Button

    private func nextButton(page: Int) -> some View {
        Button {
            withAnimation { currentPage = page }
        } label: {
            HStack(spacing: 6) {
                Text("Next")
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
        .padding(.horizontal, 32)
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
