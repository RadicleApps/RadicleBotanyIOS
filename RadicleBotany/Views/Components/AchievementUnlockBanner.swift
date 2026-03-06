import SwiftUI

/// Auto-dismissing celebration banner shown when an achievement is unlocked.
/// Slides in from the top, displays for 2.5 seconds, then fades out.
/// Non-disruptive — doesn't block user interaction.
struct AchievementUnlockBanner: View {
    let achievement: Achievement
    var onDismiss: (() -> Void)? = nil

    @State private var isVisible = false

    /// Accent color based on achievement category
    private var categoryColor: Color {
        switch achievement.category {
        case "flashcard": return .purpleSecondary
        case "learn": return .greenSecondary
        case "streak": return .orangePrimary
        case "observe": return .greenSecondary
        case "capture": return .orangePrimary
        case "journal": return .purpleSecondary
        default: return .warningAmber
        }
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(AppTypography.inter(size: 20))
                    .foregroundStyle(categoryColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievement Unlocked!")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textMuted)

                    Text(achievement.name)
                        .font(AppTypography.buttonText)
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(AppTypography.inter(size: 14))
                    .foregroundStyle(categoryColor.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(categoryColor.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: categoryColor.opacity(0.2), radius: 12, y: 4)
            .padding(.horizontal, 20)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Show & Auto-Dismiss

    func onAppear() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss?()
            }
        }
    }
}

/// Container that queues and displays achievement banners one at a time.
/// Use as an overlay on flashcard views.
struct AchievementBannerOverlay: View {
    let achievements: [Achievement]
    @Binding var currentIndex: Int
    @Binding var showBanner: Bool

    var body: some View {
        if showBanner, currentIndex < achievements.count {
            AchievementUnlockBanner(
                achievement: achievements[currentIndex],
                onDismiss: {
                    if currentIndex + 1 < achievements.count {
                        currentIndex += 1
                        // Small delay before showing next
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showBanner = true
                        }
                    } else {
                        showBanner = false
                    }
                }
            )
            .onAppear {
                // Trigger the banner's show animation
                if let banner = findBanner() {
                    banner.onAppear()
                }
            }
        }
    }

    private func findBanner() -> AchievementUnlockBanner? { nil }
}

/// Simpler banner trigger — shows achievements sequentially with auto-dismiss.
struct AchievementBannerQueue: View {
    let achievements: [Achievement]
    @State private var currentIndex = 0
    @State private var currentAchievement: Achievement?

    var body: some View {
        VStack {
            if let achievement = currentAchievement {
                AchievementUnlockBanner(achievement: achievement, onDismiss: {
                    showNext()
                })
                .onAppear {
                    triggerShow()
                }
            }
            Spacer()
        }
        .onAppear {
            if !achievements.isEmpty {
                currentAchievement = achievements[0]
            }
        }
    }

    private func triggerShow() {
        // The banner handles its own show/dismiss timing via onAppear
    }

    private func showNext() {
        currentIndex += 1
        if currentIndex < achievements.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentAchievement = achievements[currentIndex]
            }
        } else {
            currentAchievement = nil
        }
    }
}
