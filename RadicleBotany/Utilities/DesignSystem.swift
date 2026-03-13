import SwiftUI

// MARK: - Colors
/// Single source of truth for all colour tokens.
/// Theme-driven computed properties pull from ThemeManager.shared.palette,
/// so any view observing ThemeManager re-renders automatically.
///
/// COLOR PHILOSOPHY (3-colour system):
/// - Amber (#A57810)  — PRIMARY accent. Warmth, guidance, knowledge.
/// - Purple (#4b479d) — SEMANTIC attention. Urgency, danger, destructive actions.
/// - Green (#3D8B37)  — SEMANTIC green. Safety, success, positive confirmation.

struct AppColors {
    private static var palette: ThemePalette {
        MainActor.assumeIsolated { ThemeManager.shared.palette }
    }

    // ──────────────────────────────────────────────
    // MARK: Red Light Sync
    // ──────────────────────────────────────────────

    /// Set by ThemeManager whenever lightingMode changes.
    nonisolated(unsafe) static var isRedLight: Bool = false

    // ──────────────────────────────────────────────
    // MARK: Brand Accents (Red Light aware)
    // ──────────────────────────────────────────────

    /// PRIMARY accent — warm amber. Yellow in Red Light mode.
    static var primaryAmber: Color { isRedLight ? RedLight.yellow : Color(hex: "A57810") }
    /// Lighter honey gold variant.
    static var primaryHoney: Color { isRedLight ? RedLight.yellow : Color(hex: "C49420") }
    /// Muted bronze variant.
    static var primaryBronze: Color { isRedLight ? RedLight.yellowMuted : Color(hex: "7A5B0E") }

    // ──────────────────────────────────────────────
    // MARK: Semantic Status (Red Light aware)
    // ──────────────────────────────────────────────

    /// Success / safe / positive — forest green. Muted green in Red Light.
    static var success: Color { isRedLight ? RedLight.green : Color(hex: "3D8B37") }
    /// Warning / caution — amber-based. Yellow in Red Light.
    static var warning: Color { isRedLight ? RedLight.yellow : Color(hex: "A57810") }
    /// Error / danger / attention — purple. Dominant red in Red Light.
    static var error: Color { isRedLight ? RedLight.accent : Color(hex: "4b479d") }

    /// Brand purple — identity accent. Dominant red in Red Light.
    static var brandPurple: Color { isRedLight ? RedLight.accent : Color(hex: "4b479d") }

    // ──────────────────────────────────────────────
    // MARK: On-Accent
    // ──────────────────────────────────────────────

    /// Text/icon color on accent-filled surfaces. White normally, black in Red Light.
    static var onAccent: Color { isRedLight ? RedLight.onAccent : .white }

    // ──────────────────────────────────────────────
    // MARK: Backgrounds (theme-driven)
    // ──────────────────────────────────────────────

    static var appBackground: Color { palette.appBackground }
    static var cardBackground: Color { palette.cardBackground }
    static var cardElevated: Color { palette.cardElevated }
    static var surfaceOverlay: Color { palette.surfaceOverlay }
    static var border: Color { palette.border }
    static var borderSubtle: Color { palette.borderSubtle }

    // ──────────────────────────────────────────────
    // MARK: Text (theme-driven)
    // ──────────────────────────────────────────────

    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var textMuted: Color { palette.textMuted }

    // ──────────────────────────────────────────────
    // MARK: Dynamic Accent (theme-driven)
    // ──────────────────────────────────────────────

    static var accent: Color { palette.accent }

    // ──────────────────────────────────────────────
    // MARK: Semantic Aliases
    // ──────────────────────────────────────────────

    static var growth: Color { success }
    static var discovery: Color { primaryAmber }
    static var action: Color { primaryAmber }
    static var danger: Color { error }

    // Confidence (identification results)
    static var highConfidence: Color { success }
    static var mediumConfidence: Color { primaryAmber }
    static var lowConfidence: Color { error }

    // Paywall
    static var lifetimeBorder: Color { primaryAmber.opacity(0.4) }
    static var proBorder: Color { primaryAmber.opacity(0.4) }

    // ──────────────────────────────────────────────
    // MARK: Red Light Sub-Palette
    // ──────────────────────────────────────────────

    struct RedLight {
        static let accent      = Color(hex: "CC3311")   // Dominant red
        static let yellow      = Color(hex: "8B6B10")   // Guidance, progress
        static let yellowMuted = Color(hex: "5A4508")   // Subtle gold
        static let green       = Color(hex: "3D6B20")   // Success, safe
        static let onAccent    = Color(hex: "000000")   // Text on fills
    }
}

// MARK: - Typography
/// Typographic system: Cormorant Garamond (display / titles) + Inter 18pt (UI / body).
/// Editorial botanical pairing — serif for impact, sans-serif for clarity.
///
/// Font registration:
///   FontRegistration.registerInter()     — called at launch
///   FontRegistration.registerCormorant() — called at launch
///
/// SF Mono retained for GPS / technical data only.

struct AppTypography {

    // MARK: Inter Font Names

    private static let regular   = "Inter18pt-Regular"
    private static let medium    = "Inter18pt-Medium"
    private static let semiBold  = "Inter18pt-SemiBold"
    private static let bold      = "Inter18pt-Bold"
    private static let extraBold = "Inter18pt-ExtraBold"
    private static let black     = "Inter18pt-Black"

    // MARK: Cormorant Garamond Font Names

    private static let cgLight           = "CormorantGaramond-Light"
    private static let cgLightItalic     = "CormorantGaramond-LightItalic"
    private static let cgRegular         = "CormorantGaramond-Regular"
    private static let cgItalic          = "CormorantGaramond-Italic"
    private static let cgSemiBold        = "CormorantGaramond-SemiBold"
    private static let cgSemiBoldItalic  = "CormorantGaramond-SemiBoldItalic"
    private static let cgBold            = "CormorantGaramond-Bold"
    private static let cgBoldItalic      = "CormorantGaramond-BoldItalic"

    // MARK: Display (Headers & Impact) — Cormorant Garamond serif

    /// Large hero heading — Cormorant Garamond Bold 36pt
    static let displayLarge  = Font.custom(cgBold, size: 36)
    /// Section / card hero heading — Cormorant Garamond Bold 30pt
    static let displayMedium = Font.custom(cgBold, size: 30)
    /// Screen title / major section heading — Cormorant Garamond Bold 22pt
    static let headerTitle   = Font.custom(cgBold, size: 22)

    // MARK: Wordmark (brand identity — Cormorant Garamond)

    /// App wordmark at nav-bar scale — SemiBold Italic 20pt
    static let wordmark      = Font.custom(cgSemiBoldItalic, size: 20)
    /// Large wordmark for splash / onboarding — Bold Italic 32pt
    static let wordmarkLarge = Font.custom(cgBoldItalic, size: 32)

    // MARK: Interface (Navigation & Controls)

    static let sectionHeader = Font.custom(extraBold, size: 11)
    static let buttonText    = Font.custom(semiBold, size: 14)
    static let buttonLarge   = Font.custom(semiBold, size: 17)
    static let navLabel      = Font.custom(semiBold, size: 10)
    static let chipText      = Font.custom(semiBold, size: 12)

    // MARK: Body (Reading & Content)

    static let bodyText      = Font.custom(regular, size: 17)
    static let bodySmall     = Font.custom(regular, size: 15)
    static let fieldValue    = Font.custom(medium, size: 14)
    static let fieldLabel    = Font.custom(regular, size: 12)

    // MARK: Data (Numbers, Codes & Precision — SF Mono)

    static let dataValue     = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let dataLarge     = Font.system(size: 36, weight: .bold, design: .monospaced)
    static let dataStat      = Font.custom(bold, size: 20)
    static let dataMicro     = Font.system(size: 10, weight: .medium, design: .monospaced)

    // MARK: Micro (Badges, Tags, Captions)

    static let badgeText     = Font.custom(extraBold, size: 10)
    static let tagText       = Font.custom(medium, size: 12)
    static let caption       = Font.custom(regular, size: 13)
    static let captionSmall  = Font.custom(regular, size: 11)
    static let micro         = Font.custom(regular, size: 10)

    // MARK: Convenience Aliases

    static let body = bodyText
    static let interface = sectionHeader

    // MARK: Legacy inter() Helper (delegates to Font.inter)

    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.inter(size: size, weight: weight)
    }
}

// MARK: - Font.inter() Convenience

extension Font {
    /// Returns an Inter 18pt custom font for any size + weight combination.
    static func inter(size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .ultraLight, .thin, .light, .regular:
            name = "Inter18pt-Regular"
        case .medium:
            name = "Inter18pt-Medium"
        case .semibold:
            name = "Inter18pt-SemiBold"
        case .bold:
            name = "Inter18pt-Bold"
        case .heavy:
            name = "Inter18pt-ExtraBold"
        case .black:
            name = "Inter18pt-Black"
        default:
            name = "Inter18pt-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Font.cormorant() Convenience

extension Font {
    /// Returns a Cormorant Garamond font for any size + weight + italic combination.
    /// Falls back gracefully to system serif if font files are not yet added to the asset catalog.
    static func cormorant(size: CGFloat, weight: Weight = .regular, italic: Bool = false) -> Font {
        let name: String
        if italic {
            switch weight {
            case .ultraLight, .thin, .light:
                name = "CormorantGaramond-LightItalic"
            case .semibold:
                name = "CormorantGaramond-SemiBoldItalic"
            case .bold, .heavy, .black:
                name = "CormorantGaramond-BoldItalic"
            default:
                name = "CormorantGaramond-Italic"
            }
        } else {
            switch weight {
            case .ultraLight, .thin, .light:
                name = "CormorantGaramond-Light"
            case .semibold:
                name = "CormorantGaramond-SemiBold"
            case .bold, .heavy, .black:
                name = "CormorantGaramond-Bold"
            default:
                name = "CormorantGaramond-Regular"
            }
        }
        return .custom(name, size: size)
    }
}

// MARK: - Typography View Modifiers

/// Intelligence header: ALL CAPS, 2.0 kerning, muted — for domain group labels
struct IntelligenceHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.sectionHeader)
            .foregroundColor(AppColors.textMuted)
            .textCase(.uppercase)
            .kerning(2.0)
    }
}

/// Section header: ALL CAPS, 1.8 kerning, amber — for card subsection titles
struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.sectionHeader)
            .foregroundColor(AppColors.primaryAmber)
            .textCase(.uppercase)
            .kerning(1.8)
    }
}

extension View {
    func intelligenceHeader() -> some View {
        modifier(IntelligenceHeaderStyle())
    }

    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderStyle())
    }
}

// MARK: - Spacing

struct AppSpacing {
    static let screenPadding: CGFloat      = 20
    static let sectionGap: CGFloat         = 24
    static let sectionPadding: CGFloat     = 16
    static let cardPadding: CGFloat        = 16
    static let fieldGap: CGFloat           = 12
    static let componentGapSmall: CGFloat  = 8
    static let componentGapMedium: CGFloat = 12
    static let componentGapLarge: CGFloat  = 16
    static let itemGap: CGFloat            = 8
    static let tightGap: CGFloat           = 4

    // Backward compat aliases
    static let sectionMarginBottom = sectionGap
    static let fieldMarginBottom   = fieldGap
}

// MARK: - Border Radius

struct AppRadius {
    static let card: CGFloat      = 14
    static let button: CGFloat    = 10
    static let badge: CGFloat     = 16
    static let chip: CGFloat      = 20
    static let thumbnail: CGFloat = 8
    static let sheet: CGFloat     = 24
    static let small: CGFloat     = 6
}

// MARK: - Shadow Tokens

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct AppShadow {
    /// Standard card shadow — subtle grounding
    static let card = ShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    /// Elevated card shadow — lifted surfaces, modals
    static let elevated = ShadowStyle(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    /// Interactive element shadow — buttons, tappable cards
    static let interactive = ShadowStyle(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
}

extension View {
    func appShadow(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Animation Tokens

struct AppAnimations {
    static let interactiveSpring: Animation = .spring(response: 0.35, dampingFraction: 0.86)
    static let modalReveal: Animation = .spring(response: 0.5, dampingFraction: 0.85)
    static let fade: Animation = .easeOut(duration: 0.2)
    static let themeSwitch: Animation = .easeInOut(duration: 0.6)
    static let dismiss: Animation = .easeOut(duration: 0.25)
    static let buttonPress: Animation = .easeInOut(duration: 0.15)
}

// MARK: - Card Style

enum CardRole {
    case `static`
    case interactive
    case container
}

struct CardStyleModifier: ViewModifier {
    let role: CardRole
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(elevated ? AppColors.cardElevated : AppColors.cardBackground)
            .cornerRadius(AppRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .strokeBorder(borderColor, lineWidth: role == .interactive ? 1.0 : 0.5)
            )
            .appShadow(shadowStyle)
    }

    private var borderColor: Color {
        switch role {
        case .interactive: return AppColors.accent.opacity(0.4)
        case .static, .container: return AppColors.borderSubtle
        }
    }

    private var shadowStyle: ShadowStyle {
        switch role {
        case .interactive: return AppShadow.interactive
        case .static:      return elevated ? AppShadow.elevated : AppShadow.card
        case .container:   return AppShadow.card
        }
    }
}

extension View {
    /// Role-based card styling
    func cardStyle(_ role: CardRole = .static, elevated: Bool = false) -> some View {
        modifier(CardStyleModifier(role: role, elevated: elevated))
    }

    /// Backward compat for `.cardStyle(elevated:interactive:)` call sites
    func cardStyle(elevated: Bool, interactive: Bool) -> some View {
        let role: CardRole = interactive ? .interactive : .static
        return modifier(CardStyleModifier(role: role, elevated: elevated))
    }
}

// MARK: - Button Styles

/// Accent opacity background + border (main CTA)
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color? = nil
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let accentColor = isDestructive ? AppColors.error : (color ?? AppColors.accent)

        configuration.label
            .font(AppTypography.buttonText)
            .foregroundColor(accentColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(accentColor.opacity(configuration.isPressed ? 0.14 : 0.08))
            .cornerRadius(AppRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .strokeBorder(accentColor.opacity(0.25), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Accent opacity background + thicker border (secondary CTA)
struct SecondaryButtonStyle: ButtonStyle {
    var color: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        let accentColor = color ?? AppColors.accent

        configuration.label
            .font(AppTypography.buttonText)
            .foregroundColor(accentColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(accentColor.opacity(configuration.isPressed ? 0.16 : 0.1))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(AppRadius.button)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Minimal border, muted text (ghost action)
struct GhostButtonStyle: ButtonStyle {
    var color: Color? = nil
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let accentColor = isDestructive ? AppColors.error : (color ?? AppColors.textSecondary)

        configuration.label
            .font(AppTypography.buttonText)
            .foregroundColor(accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .strokeBorder(AppColors.borderSubtle.opacity(0.5), lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Border-only outline with optional destructive variant
struct OutlineButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonText)
            .foregroundColor(isDestructive ? AppColors.error : AppColors.textSecondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(isDestructive ? AppColors.error.opacity(0.5) : AppColors.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

/// Solid accent background, white text — prominent CTA
struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonLarge)
            .foregroundColor(AppColors.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(AppColors.accent)
            )
            .shadow(color: AppColors.accent.opacity(0.25), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Tappable card press effect — scale + shadow lift
struct InteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.0 : 0.06),
                radius: configuration.isPressed ? 1 : 4,
                x: 0,
                y: configuration.isPressed ? 0 : 2
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 4-variant intelligent button: primary amber filled, secondary amber border,
/// tertiary text, destructive purple
struct IntelligentButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case tertiary
        case destructive

        var foregroundColor: Color {
            switch self {
            case .primary: return AppColors.onAccent
            case .secondary: return AppColors.primaryAmber
            case .tertiary: return AppColors.textSecondary
            case .destructive: return AppColors.error
            }
        }

        var backgroundColor: Color {
            switch self {
            case .primary: return AppColors.primaryAmber
            case .secondary, .tertiary, .destructive: return Color.clear
            }
        }

        var borderColor: Color? {
            switch self {
            case .primary, .tertiary: return nil
            case .secondary: return AppColors.primaryAmber.opacity(0.3)
            case .destructive: return AppColors.error.opacity(0.3)
            }
        }
    }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.inter(size: 15, weight: .medium))
            .foregroundColor(variant.foregroundColor)
            .padding(.horizontal, variant == .tertiary ? 8 : 20)
            .padding(.vertical, variant == .tertiary ? 6 : 12)
            .background(
                RoundedRectangle(cornerRadius: variant == .tertiary ? 8 : 12)
                    .fill(variant.backgroundColor)
                    .overlay(
                        variant.borderColor.map { color in
                            RoundedRectangle(cornerRadius: variant == .tertiary ? 8 : 12)
                                .stroke(color, lineWidth: 1)
                        }
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == IntelligentButtonStyle {
    static var primaryButton: IntelligentButtonStyle {
        IntelligentButtonStyle(variant: .primary)
    }
    static var secondaryButton: IntelligentButtonStyle {
        IntelligentButtonStyle(variant: .secondary)
    }
    static var tertiaryButton: IntelligentButtonStyle {
        IntelligentButtonStyle(variant: .tertiary)
    }
    static var destructiveButton: IntelligentButtonStyle {
        IntelligentButtonStyle(variant: .destructive)
    }
}

// MARK: - Animation Constants

struct AppAnimation {
    static let interactiveSpring = Animation.spring(response: 0.35, dampingFraction: 0.86)
    static let modalReveal = Animation.spring(response: 0.5, dampingFraction: 0.85)
    static let notificationSpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let fade = Animation.easeOut(duration: 0.2)
    static let themeSwitch = Animation.easeInOut(duration: 0.6)
    static let dismiss = Animation.easeOut(duration: 0.25)
    static let buttonPress = Animation.easeInOut(duration: 0.15)
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
            (a, r, g, b) = (1, 1, 1, 0)
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

// MARK: - Semantic Color Palette (Color extension statics)

extension Color {
    // Primary accent tones
    static let orangePrimary = Color(hex: "A57810")
    static let orangeLight = Color(hex: "C49420")

    // Warning
    static let warningAmber = Color(hex: "A57810")

    // Green tones
    static let greenSecondary = Color(hex: "3D8B37")
    static let greenLight = Color(hex: "4D9B47")
    static let greenDark = Color(hex: "2D6B27")

    // Purple tones (RadicleBotany identity)
    static let purpleSecondary = Color(hex: "4b479d")
    static let purpleLight = Color(hex: "5D59B0")

    // Semantic aliases
    static let successGreen = Color(hex: "3D8B37")
    static let errorPurple = Color(hex: "4b479d")
    static let errorRed = Color(hex: "C53030")  // True red for critical/danger states
    static let highConfidence = Color(hex: "3D8B37")
    static let mediumConfidence = Color(hex: "A57810")
    static let lowConfidence = Color(hex: "4b479d")
}

// MARK: - Haptic Feedback

enum HapticFeedback {
    static func identify() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func save() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func delete() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let text: String
    var color: Color = AppColors.primaryAmber

    var body: some View {
        Text(text)
            .font(AppTypography.tagText)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Filter Chip Bar

struct FilterChipBar: View {
    let categories: [String]
    @Binding var selectedCategory: String?
    var accentColor: Color = AppColors.primaryAmber

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                ForEach(categories, id: \.self) { category in
                    filterChip(title: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenPadding)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let bgColor: Color = isSelected ? accentColor : AppColors.cardElevated
        let fgColor: Color = isSelected ? AppColors.onAccent : AppColors.textSecondary
        let borderColor: Color = isSelected ? accentColor : AppColors.border

        return Button(action: action) {
            Text(title)
                .font(AppTypography.chipText)
                .foregroundStyle(fgColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(bgColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
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
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }
}

// MARK: - At Risk Badge

struct AtRiskBadge: View {
    let status: String

    var badgeColor: Color {
        switch status {
        case "Critically Endangered", "Endangered":
            return AppColors.error
        default:
            return AppColors.warning
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AppTypography.inter(size: 10))
            Text(status)
                .font(AppTypography.tagText)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Collection Header

struct CollectionHeader: View {
    let icon: String
    let title: String
    let count: Int
    let total: Int
    var color: Color = AppColors.primaryAmber

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 13))
                .foregroundStyle(color)

            Text(title)
                .font(AppTypography.buttonText)
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text(count == total ? "\(total)" : "\(count)/\(total)")
                .font(AppTypography.dataMicro)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Inline Search Field

struct InlineSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.inter(size: 12))
                .foregroundStyle(AppColors.textMuted)

            TextField(placeholder, text: $text)
                .font(AppTypography.fieldLabel)
                .foregroundStyle(AppColors.textPrimary)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypography.inter(size: 12))
                        .foregroundStyle(AppColors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.button).stroke(AppColors.border, lineWidth: 0.5))
    }
}

// MARK: - Mini Filter Chip

struct MiniFilterChip: View {
    let name: String
    let isSelected: Bool
    var color: Color = AppColors.primaryAmber
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(AppTypography.caption)
                .foregroundStyle(isSelected ? AppColors.onAccent : AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? color : AppColors.cardElevated)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? color : AppColors.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mini Empty State

struct MiniEmptyState: View {
    let icon: String
    let text: String
    var color: Color = AppColors.primaryAmber

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(AppTypography.inter(size: 14))
                .foregroundStyle(color.opacity(0.4))
            Text(text)
                .font(AppTypography.tagText)
                .foregroundStyle(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppColors.cardElevated.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }
}

// MARK: - Formatting Helpers

func formatXP(_ xp: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: xp)) ?? "\(xp)"
}

func markdownToAttributed(_ text: String) -> AttributedString {
    do {
        return try AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    } catch {
        return AttributedString(text)
    }
}
