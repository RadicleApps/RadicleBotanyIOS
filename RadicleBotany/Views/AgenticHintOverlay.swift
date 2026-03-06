import SwiftUI

/// Subtle, contextual hint overlay at the bottom of the screen.
/// Uses TypewriterText for agentic feel. Pulsing colored dot indicates system presence.
///
/// Semantic dot colors:
///   - .action (amber) — "do this next"
///   - .insight (purple) — "here's why/how"
///   - .success (green) — "you've achieved something"
struct AgenticHintOverlay: View {
    let hint: ContextualHint
    let isVisible: Bool
    let onDismiss: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack {
            Spacer()

            if isVisible {
                HStack(spacing: 10) {
                    // Pulsing system indicator
                    ZStack {
                        Circle()
                            .fill(hint.semanticColor.color.opacity(0.2))
                            .frame(width: 20, height: 20)
                            .scaleEffect(pulseScale)
                            .opacity(2.0 - pulseScale)

                        Circle()
                            .fill(hint.semanticColor.color)
                            .frame(width: 6, height: 6)
                    }
                    .frame(width: 20, height: 20)

                    TypewriterText(hint.message, style: hint.style)
                        .animated()
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(AppTypography.inter(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.textMuted)
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(AppColors.cardElevated)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    startPulse()
                }
            }
        }
        .allowsHitTesting(isVisible)
        .animation(AppAnimation.notificationSpring, value: isVisible)
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.5
        }
    }
}

/// View modifier to attach the agentic hint system to any view
struct AgenticHintModifier: ViewModifier {
    @ObservedObject var guidanceService = ContextualGuidanceService.shared

    func body(content: Content) -> some View {
        ZStack {
            content

            if let hint = guidanceService.currentHint {
                AgenticHintOverlay(
                    hint: hint,
                    isVisible: guidanceService.shouldShowHint,
                    onDismiss: {
                        guidanceService.dismissCurrentHint()
                    }
                )
            }
        }
    }
}

extension View {
    func withAgenticGuidance() -> some View {
        modifier(AgenticHintModifier())
    }
}

// MARK: - Ambient Status Indicator

struct AgenticPresenceIndicator: View {
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(AppColors.primaryAmber.opacity(0.6))
            .frame(width: 6, height: 6)
            .scaleEffect(pulse)
            .opacity(2.0 - pulse)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulse = 1.4
                }
            }
    }
}
