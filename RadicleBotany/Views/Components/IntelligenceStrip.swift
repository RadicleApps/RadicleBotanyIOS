import SwiftUI

/// Intelligence Strip — persistent contextual status bar below the navigation bar.
///
/// Single surface for live intelligence: contextual hints, status updates, notifications.
/// Uses pulsing dot + monospaced text aesthetic.
///
/// Activated on every screen via `.appToolbar()` → `.safeAreaInset`.
/// Collapses to zero height when no message is active.
///
/// Semantic color system:
///   Orange = action ("do this next")
///   Purple = insight ("here's why/how")
///   Green  = success ("system confirmed")

struct IntelligenceStrip: View {
    @ObservedObject private var guidanceService = ContextualGuidanceService.shared

    @State private var pulseScale: CGFloat = 1.0
    @State private var displayedText = ""
    @State private var messageOpacity: Double = 0
    @State private var currentMessageID: UUID?

    var body: some View {
        if guidanceService.shouldShowStrip, let message = guidanceService.activeStripMessage {
            HStack(spacing: 8) {
                // Pulsing semantic-colored dot
                Circle()
                    .fill(message.semanticColor.color)
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                // Monospaced text — crossfade between messages
                Text(displayedText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .opacity(messageOpacity)

                Spacer(minLength: 4)

                // Dismiss button
                Button {
                    guidanceService.dismissStrip()
                } label: {
                    Image(systemName: "xmark")
                        .font(AppTypography.inter(size: 8, weight: .bold))
                        .foregroundColor(AppColors.textMuted.opacity(0.5))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.vertical, 6)
            .background(AppColors.appBackground)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onAppear {
                pulseScale = 1.4
                crossfadeTo(message.text)
                currentMessageID = message.id
            }
            .onChange(of: guidanceService.activeStripMessage?.id) { newID in
                guard let newID = newID,
                      newID != currentMessageID,
                      let newMessage = guidanceService.activeStripMessage else { return }
                currentMessageID = newID
                crossfadeTo(newMessage.text)
            }
        }
    }

    // MARK: - Crossfade Animation

    private func crossfadeTo(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) {
            messageOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            displayedText = text
            withAnimation(.easeIn(duration: 0.2)) {
                messageOpacity = 1
            }
        }
    }
}
