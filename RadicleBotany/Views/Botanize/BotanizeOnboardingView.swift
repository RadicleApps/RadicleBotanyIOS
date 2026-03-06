import SwiftUI

struct BotanizeOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let totalPages = 3

    var body: some View {
        ZStack {
            AppColors.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button {
                            dismiss()
                        } label: {
                            Text("Skip")
                                .font(AppTypography.tagText)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .frame(height: 40)

                // Pages
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    snapPage.tag(1)
                    observePage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom controls
                VStack(spacing: 16) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? AppColors.primaryAmber : AppColors.textMuted.opacity(0.3))
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }

                    // Next / Get Started button
                    Button {
                        if currentPage < totalPages - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .orangePrimary))
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                Image("Sequential Morphology of Emergence")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 140)
                    .opacity(0.85)

                VStack(spacing: 10) {
                    Text("Identify Any Plant")
                        .font(AppTypography.inter(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Three tools to help you identify plants in the field.")
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    modeCard(
                        icon: "camera.fill",
                        iconColor: AppColors.primaryAmber,
                        title: "Snap",
                        description: "Photograph a plant to identify it"
                    )

                    modeCard(
                        icon: "eye.fill",
                        iconColor: AppColors.success,
                        title: "Observe",
                        description: "Select visible traits to narrow down species"
                    )

                    modeCard(
                        icon: "sparkles",
                        iconColor: AppColors.brandPurple,
                        title: "Both",
                        description: "Combine photo + traits for best accuracy"
                    )
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)
            }
        }
    }

    // MARK: - Page 2: How Snap Works

    private var snapPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                Image("Actinomorphic (symmetry) color")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
                    .opacity(0.85)

                VStack(spacing: 10) {
                    Text("Point, Shoot, Identify")
                        .font(AppTypography.inter(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Photo identification in seconds.")
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    stepRow(number: 1, text: "Select the plant part you're photographing", detail: "Flower, leaf, fruit, or bark")
                    stepRow(number: 2, text: "Take a photo or choose from your library", detail: "Close-up shots work best")
                    stepRow(number: 3, text: "Image is analyzed for species matches", detail: "Results ranked by confidence score")
                    stepRow(number: 4, text: "Review ranked results", detail: "Each match includes a confidence score")
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)
            }
        }
    }

    // MARK: - Page 3: How Observe Works

    private var observePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                Image("Zygomorphic (symmetry) color")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
                    .opacity(0.85)

                VStack(spacing: 10) {
                    Text("Trait-Based Keying")
                        .font(AppTypography.inter(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Identify plants by what you can see — no camera needed.")
                        .font(AppTypography.bodyText)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 16) {
                    stepRow(number: 1, text: "Pick the organ you're examining", detail: "Leaf, flower, fruit, stem, root, or bark")
                    stepRow(number: 2, text: "Browse illustrated traits", detail: "Select what matches your specimen")
                    stepRow(number: 3, text: "Each selection narrows the list", detail: "Match count updates in real time")
                    stepRow(number: 4, text: "Tap \"Find Matches\" to see results", detail: "Ranked by how many traits match")
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)
            }
        }
    }

    // MARK: - Reusable Components

    private func modeCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(AppTypography.inter(size: 18))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Text(description)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColors.border, lineWidth: 0.5)
        )
    }

    private func stepRow(number: Int, text: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.primaryAmber)
                .frame(width: 28, height: 28)
                .background(AppColors.primaryAmber.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary)

                Text(detail)
                    .font(AppTypography.tagText)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BotanizeOnboardingView()
        .preferredColorScheme(.dark)
}
