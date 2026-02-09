import SwiftUI

// MARK: - Brand Colors

extension Color {
    // Backgrounds
    static let appBackground = Color(hex: "0a0a0a")
    static let surface = Color(hex: "141416")
    static let surfaceElevated = Color(hex: "1c1c20")
    static let borderSubtle = Color(hex: "2a2a2e")

    // Text
    static let textPrimary = Color(hex: "fafafa")
    static let textSecondary = Color(hex: "a0a0a8")
    static let textMuted = Color(hex: "666670")

    // Brand
    static let orangePrimary = Color(hex: "a13d09")
    static let orangeLight = Color(hex: "c4540f")
    static let greenSecondary = Color(hex: "999d47")
    static let greenLight = Color(hex: "b5b962")
    static let purpleSecondary = Color(hex: "4b479d")
    static let purpleLight = Color(hex: "6b66c4")

    // Semantic
    static let successGreen = Color(hex: "65a30d")
    static let warningAmber = Color(hex: "ca8a04")
    static let errorRed = Color(hex: "b91c1c")

    // Confidence
    static let highConfidence = Color(hex: "65a30d")
    static let mediumConfidence = Color(hex: "ca8a04")
    static let lowConfidence = Color(hex: "b91c1c")

    // Paywall
    static let lifetimeBorder = Color(hex: "a13d09").opacity(0.4)
    static let proBorder = Color(hex: "999d47").opacity(0.4)
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

struct AppFont {
    static func title(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .bold)
    }

    static func sectionHeader(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium)
    }

    static func bodyLarge(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular)
    }

    static func italic(_ size: CGFloat = 14) -> Font {
        .system(size: size).italic()
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .orangePrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.sectionHeader())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = .orangePrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.sectionHeader())
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var color: Color = .textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.caption())
            .foregroundStyle(color)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card Style Modifier

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderSubtle, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let text: String
    var color: Color = .purpleSecondary

    var body: some View {
        Text(text)
            .font(AppFont.caption())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Lock Overlay

struct LockOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            Image(systemName: "lock.fill")
                .foregroundStyle(.white.opacity(0.7))
                .font(.title3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - At Risk Badge

struct AtRiskBadge: View {
    let status: String

    var badgeColor: Color {
        status == "Critical" ? .errorRed : .warningAmber
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(status)
                .font(AppFont.caption())
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Markdown Helper

/// Converts a markdown string to an AttributedString for SwiftUI Text rendering.
func markdownToAttributed(_ text: String) -> AttributedString {
    do {
        return try AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    } catch {
        return AttributedString(text)
    }
}
