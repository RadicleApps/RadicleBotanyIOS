import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager

    var experience: BotanicalExperience? = nil
    var goals: [BotanicalGoal] = []

    @State private var showError = false
    @State private var purchaseInProgress = false

    var personalizedHeadline: String {
        switch experience {
        case .novice:       return "Start your botanical journey right."
        case .enthusiast:   return "Take your plant knowledge further."
        case .student:      return "Everything a botany student needs."
        case .professional: return "Built for field botanists."
        case nil:           return "Unlock the full botanical experience."
        }
    }

    var body: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if storeManager.isLoadingProducts && storeManager.products.isEmpty {
                        productsLoadingState
                    } else {
                        headerSection
                        annualCard
                        ctaButton
                        footerSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
                .frame(maxWidth: 500) // iPad: constrain content width
            }
            .frame(maxWidth: .infinity) // Center the constrained content

            // Dismiss button
            dismissButton

            // Loading overlay (for purchases only)
            if storeManager.isLoading || purchaseInProgress {
                loadingOverlay
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            if storeManager.products.isEmpty {
                await storeManager.fetchProducts()
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

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.inter(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.cardElevated)
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.top, 12)
            }
            Spacer()
        }
    }

    // MARK: - Products Loading State

    private var productsLoadingState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 80)

            ProgressView()
                .tint(AppColors.primaryAmber)
                .scaleEffect(1.2)

            Text("Loading plans...")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()
                .frame(height: 80)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

            Text(personalizedHeadline)
                .font(AppTypography.headerTitle)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Start your 7-day free trial, cancel anytime.")
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - RadicleBotany Card

    private var annualCard: some View {
        VStack(spacing: 16) {
            // Header row
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

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                featureRow("All species & families", color: .orangePrimary)
                featureRow("Botanical terms", color: .orangePrimary)
                featureRow("Unlimited Observe mode", color: .orangePrimary)
                featureRow("Journal & Collections", color: .orangePrimary)
                featureRow("Flashcards & study streaks", color: .orangePrimary)
                featureRow("Photo Identification", color: .orangePrimary)
                featureRow("Both mode", color: .orangePrimary)
                featureRow("Plant Assistant", color: .orangePrimary)
                featureRow("iCloud sync across devices", color: .orangePrimary)
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

    // MARK: - CTA Button

    private var ctaButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchaseSelected() }
            } label: {
                Text("Start 7-Day Free Trial")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
            .disabled(storeManager.isLoading || purchaseInProgress || storeManager.annualProduct == nil)

            let price = storeManager.annualProduct?.displayPrice ?? "$33.99"
            Text("Then \(price)/year · cancel anytime")
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
    }

    private var selectedProduct: Product? {
        storeManager.annualProduct
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    await storeManager.restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.brandPurple)
            }
            .disabled(storeManager.isLoading || purchaseInProgress)

            HStack(spacing: 20) {
                Link("Terms of Use", destination: URL(string: "https://radiclebotany.app/dl/f3f484")!)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)

                Link("Privacy Policy", destination: URL(string: "https://radiclebotany.app/dl/29abc7")!)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }

            let price = storeManager.annualProduct?.displayPrice ?? "$33.99"
            Text("RadicleBotany subscription: \(price)/year after 7-day free trial. Payment charged to Apple ID at confirmation. Auto-renews yearly unless cancelled at least 24 hours before period end. Manage in Apple ID Account Settings.")
                .font(AppTypography.inter(size: 10))
                .foregroundStyle(AppColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
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

    // MARK: - Feature Row

    private func featureRow(_ text: String, color: Color = .secondary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(AppTypography.inter(size: 16))
                .foregroundStyle(color)

            Text(text)
                .font(AppTypography.bodyText)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Purchase Action

    private func purchaseSelected() async {
        guard let product = selectedProduct else {
            await storeManager.fetchProducts()
            if selectedProduct == nil {
                storeManager.errorMessage = "Unable to load products. Please check your connection and try again."
            }
            return
        }
        purchaseInProgress = true
        let success = await storeManager.purchase(product)
        purchaseInProgress = false
        if success { dismiss() }
    }

}

#Preview {
    PaywallView(experience: .enthusiast, goals: [.identify, .learn])
        .environmentObject(StoreManager(preview: true))
}
