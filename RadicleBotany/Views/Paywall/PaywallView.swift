import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager

    var contextText: String?

    @State private var showError = false
    @State private var purchaseInProgress = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    lifetimeCard
                    proCard
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }

            // Dismiss button
            dismissButton

            // Loading overlay
            if storeManager.isLoading || purchaseInProgress {
                loadingOverlay
            }
        }
        .presentationDetents([.large])
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.surfaceElevated)
                        .clipShape(Circle())
                }
                .padding(.trailing, 20)
                .padding(.top, 12)
            }
            Spacer()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.orangePrimary)

                Text("Unlock RadicleBotany")
                    .font(AppFont.title())
                    .foregroundStyle(Color.textPrimary)
            }
            .padding(.top, 40)

            if let contextText {
                Text(contextText)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Lifetime Card

    private var lifetimeCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("LIFETIME")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.orangePrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orangePrimary.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                Text(storeManager.lifetimeProduct?.displayPrice ?? "$24.99")
                    .font(AppFont.title(22))
                    .foregroundStyle(Color.textPrimary)
            }

            // Bullet points
            VStack(alignment: .leading, spacing: 10) {
                featureRow("179 species & 183 families")
                featureRow("464 botanical terms")
                featureRow("Full Observe mode")
                featureRow("Journal & Collections")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Purchase button
            Button {
                Task {
                    await purchaseLifetime()
                }
            } label: {
                Text("Get Lifetime Access")
            }
            .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
            .disabled(storeManager.isLoading || purchaseInProgress)
        }
        .padding(20)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.lifetimeBorder, lineWidth: 1)
        )
    }

    // MARK: - Pro Card

    private var proCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("PRO")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.greenSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.greenSecondary.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(storeManager.proYearlyProduct?.displayPrice ?? "$19.99/year")
                        .font(AppFont.title(22))
                        .foregroundStyle(Color.textPrimary)

                    Text("7-day free trial")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.greenLight)
                }
            }

            // Description
            Text("Everything in Lifetime, plus:")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Bullet points
            VStack(alignment: .leading, spacing: 10) {
                featureRow("AI plant identification", color: .greenSecondary)
                featureRow("iCloud sync across devices", color: .greenSecondary)
                featureRow("Seasonal updates", color: .greenSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Purchase button
            Button {
                Task {
                    await purchaseProYearly()
                }
            } label: {
                Text("Start Free Trial")
            }
            .buttonStyle(PrimaryButtonStyle(color: .greenSecondary))
            .disabled(storeManager.isLoading || purchaseInProgress)

            // Monthly option
            if let monthlyProduct = storeManager.proMonthlyProduct {
                Button {
                    Task {
                        await purchaseProMonthly(monthlyProduct)
                    }
                } label: {
                    Text("or \(monthlyProduct.displayPrice)/month")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                        .underline()
                }
                .disabled(storeManager.isLoading || purchaseInProgress)
            } else {
                Button {
                    Task {
                        await purchaseProMonthlyFallback()
                    }
                } label: {
                    Text("or $2.99/month")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textMuted)
                        .underline()
                }
                .disabled(storeManager.isLoading || purchaseInProgress)
            }
        }
        .padding(20)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.proBorder, lineWidth: 1)
        )
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
                    .font(AppFont.caption())
                    .foregroundStyle(Color.purpleSecondary)
            }
            .disabled(storeManager.isLoading || purchaseInProgress)

            HStack(spacing: 20) {
                Link("Terms of Use", destination: URL(string: "https://radiclebotany.com/terms")!)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)

                Link("Privacy Policy", destination: URL(string: "https://radiclebotany.com/privacy")!)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textMuted)
            }
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
                    .tint(Color.orangePrimary)
                    .scaleEffect(1.2)

                Text("Processing...")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(32)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Feature Row

    private func featureRow(_ text: String, color: Color = .orangePrimary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Purchase Actions

    private func purchaseLifetime() async {
        guard let product = storeManager.lifetimeProduct else { return }
        purchaseInProgress = true
        let success = await storeManager.purchase(product)
        purchaseInProgress = false
        if success {
            dismiss()
        }
    }

    private func purchaseProYearly() async {
        guard let product = storeManager.proYearlyProduct else { return }
        purchaseInProgress = true
        let success = await storeManager.purchase(product)
        purchaseInProgress = false
        if success {
            dismiss()
        }
    }

    private func purchaseProMonthly(_ product: Product) async {
        purchaseInProgress = true
        let success = await storeManager.purchase(product)
        purchaseInProgress = false
        if success {
            dismiss()
        }
    }

    private func purchaseProMonthlyFallback() async {
        guard let product = storeManager.proMonthlyProduct else { return }
        purchaseInProgress = true
        let success = await storeManager.purchase(product)
        purchaseInProgress = false
        if success {
            dismiss()
        }
    }
}

#Preview {
    PaywallView(contextText: "Unlock this species to view all details")
        .environmentObject(StoreManager())
}
