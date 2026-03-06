import SwiftUI

/// In-app notification banner with word-fade animation.
///
/// Three types for botany context:
///   - .discovery — Amber dot, secondary text, 2.0s hold
///   - .achievement — Green dot, green text, 3.5s hold
///   - .alert — Red dot, red text, 4.0s hold
struct NotificationBanner: View {
    let title: String
    let type: BannerType
    var onTap: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var visibleWordCount = 0
    @State private var isComplete = false
    @State private var isPulsing = false
    @State private var holdComplete = false

    private var words: [String] {
        title.split(separator: " ").map(String.init)
    }

    enum BannerType {
        case discovery    // Amber dot, secondary text
        case achievement  // Green dot, green text
        case alert        // Red dot, red text

        var dotColor: Color {
            switch self {
            case .discovery: return AppColors.primaryAmber
            case .achievement: return AppColors.success
            case .alert: return AppColors.error
            }
        }

        var textColor: Color {
            switch self {
            case .discovery: return AppColors.textSecondary
            case .achievement: return AppColors.success
            case .alert: return AppColors.error
            }
        }

        var holdDuration: TimeInterval {
            switch self {
            case .discovery: return 2.0
            case .achievement: return 3.5
            case .alert: return 4.0
            }
        }

        var hasBorderGlow: Bool {
            switch self {
            case .achievement, .alert: return true
            case .discovery: return false
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(type.dotColor)
                .frame(width: 6, height: 6)
                .opacity(isPulsing ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)

            HStack(spacing: 0) {
                ForEach(0..<words.count, id: \.self) { index in
                    Text(index < words.count - 1 ? words[index] + " " : words[index])
                        .font(AppTypography.dataValue)
                        .foregroundColor(type.textColor)
                        .opacity(index < visibleWordCount ? 1 : 0)
                        .animation(.easeOut(duration: 0.15), value: visibleWordCount)
                }
            }

            Spacer()

            if isComplete {
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.inter(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 20, height: 20)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.badge)
                .fill(AppColors.cardBackground)
                .overlay(
                    type.hasBorderGlow ?
                    RoundedRectangle(cornerRadius: AppRadius.badge)
                        .stroke(type.dotColor.opacity(0.3), lineWidth: 1)
                    : nil
                )
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            isPulsing = true
            startWordReveal()
        }
    }

    private func startWordReveal() {
        revealNextWord()
    }

    private func revealNextWord() {
        guard visibleWordCount < words.count else {
            withAnimation(.easeOut(duration: 0.2)) {
                isComplete = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + type.holdDuration) {
                if !holdComplete {
                    holdComplete = true
                    onDismiss?()
                }
            }
            return
        }

        visibleWordCount += 1

        let word = words[visibleWordCount - 1]
        let delay = delayForWord(word)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            revealNextWord()
        }
    }

    private func delayForWord(_ word: String) -> TimeInterval {
        let base: TimeInterval = 0.06

        guard let lastChar = word.last else { return base }

        switch lastChar {
        case ".", "!": return base * 2.5
        case "?": return base * 3.0
        case ",": return base * 1.8
        case ":": return base * 2.0
        case "\u{2014}", "\u{2013}": return base * 3.0
        default: return base
        }
    }
}

// MARK: - Banner Container

struct NotificationBannerOverlay: View {
    @State private var currentBanner: BannerItem?
    @State private var isVisible = false

    struct BannerItem: Identifiable {
        let id = UUID()
        let title: String
        let type: NotificationBanner.BannerType
        var onTap: (() -> Void)?
    }

    var body: some View {
        VStack {
            if isVisible, let banner = currentBanner {
                NotificationBanner(
                    title: banner.title,
                    type: banner.type,
                    onTap: {
                        dismissBanner()
                        banner.onTap?()
                    },
                    onDismiss: {
                        dismissBanner()
                    }
                )
                .padding(.horizontal, AppSpacing.screenPadding)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showNotificationBanner)) { notification in
            if let title = notification.userInfo?["title"] as? String {
                let typeString = notification.userInfo?["type"] as? String ?? "discovery"
                let type: NotificationBanner.BannerType
                switch typeString {
                case "achievement": type = .achievement
                case "alert": type = .alert
                default: type = .discovery
                }

                showBanner(BannerItem(title: title, type: type))
            }
        }
    }

    private func showBanner(_ item: BannerItem) {
        currentBanner = item
        withAnimation(AppAnimation.notificationSpring) {
            isVisible = true
        }
    }

    private func dismissBanner() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            currentBanner = nil
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let showNotificationBanner = Notification.Name("showNotificationBanner")
}

// MARK: - Convenience

extension NotificationBannerOverlay {
    /// Fire a banner from anywhere in the app
    static func show(title: String, type: String = "discovery") {
        NotificationCenter.default.post(
            name: .showNotificationBanner,
            object: nil,
            userInfo: [
                "title": title,
                "type": type
            ]
        )
    }
}
