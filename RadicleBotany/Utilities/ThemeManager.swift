import SwiftUI
import Combine

// MARK: - Lighting Modes

enum LightingMode: String, CaseIterable, Identifiable {
    case night
    case light
    case dawn
    case dusk
    case redLight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .night:    return "Night"
        case .light:    return "Light"
        case .dawn:     return "Dawn"
        case .dusk:     return "Dusk"
        case .redLight: return "Red Light"
        }
    }

    var icon: String {
        switch self {
        case .night:    return "moon.stars"
        case .light:    return "sun.min"
        case .dawn:     return "sunrise"
        case .dusk:     return "sunset"
        case .redLight: return "flashlight.on.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .night:    return "Deep dark — default"
        case .light:    return "Daylight readable"
        case .dawn:     return "Sunrise warmth"
        case .dusk:     return "Golden hour"
        case .redLight: return "Night vision safe"
        }
    }
}

// MARK: - Theme Palette

struct ThemePalette: Equatable {
    let appBackground: Color
    let cardBackground: Color
    let cardElevated: Color
    let surfaceOverlay: Color
    let border: Color
    let borderSubtle: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color

    // UIKit bridges
    var uiAppBackground: UIColor  { UIColor(appBackground) }
    var uiCardBackground: UIColor { UIColor(cardBackground) }
    var uiCardElevated: UIColor   { UIColor(cardElevated) }
    var uiBorder: UIColor         { UIColor(border) }
    var uiTextPrimary: UIColor    { UIColor(textPrimary) }
    var uiTextSecondary: UIColor  { UIColor(textSecondary) }
    var uiTextMuted: UIColor      { UIColor(textMuted) }
    var uiAccent: UIColor         { UIColor(accent) }
}

// MARK: - Palette Definitions

extension ThemePalette {

    /// Deep dark — warm blacks, default mode
    static func night(accent: Color) -> ThemePalette {
        ThemePalette(
            appBackground:  Color(hex: "0A0A0A"),
            cardBackground: Color(hex: "141414"),
            cardElevated:   Color(hex: "1E1E1E"),
            surfaceOverlay: Color(hex: "1A1A1A"),
            border:         Color(hex: "333333"),
            borderSubtle:   Color(hex: "222222"),
            textPrimary:    Color(hex: "FAFAFA"),
            textSecondary:  Color(hex: "999999"),
            textMuted:      Color(hex: "555555"),
            accent:         accent
        )
    }

    /// Lifted dark — higher contrast for outdoor readability
    static func light(accent: Color) -> ThemePalette {
        ThemePalette(
            appBackground:  Color(hex: "1C1E22"),
            cardBackground: Color(hex: "262830"),
            cardElevated:   Color(hex: "2E3038"),
            surfaceOverlay: Color(hex: "22242A"),
            border:         Color(hex: "4E5060"),
            borderSubtle:   Color(hex: "3A3C48"),
            textPrimary:    Color(hex: "F0F0F4"),
            textSecondary:  Color(hex: "A0A0A8"),
            textMuted:      Color(hex: "6A6A74"),
            accent:         accent
        )
    }

    /// Sunrise warmth — cool violet undertones
    static func dawn(accent: Color) -> ThemePalette {
        ThemePalette(
            appBackground:  Color(hex: "121216"),
            cardBackground: Color(hex: "1C1C22"),
            cardElevated:   Color(hex: "26262E"),
            surfaceOverlay: Color(hex: "18181E"),
            border:         Color(hex: "3E3E48"),
            borderSubtle:   Color(hex: "2C2C34"),
            textPrimary:    Color(hex: "E8E8EE"),
            textSecondary:  Color(hex: "9898A0"),
            textMuted:      Color(hex: "5C5C66"),
            accent:         accent
        )
    }

    /// Golden hour — warm olive undertones
    static func dusk(accent: Color) -> ThemePalette {
        ThemePalette(
            appBackground:  Color(hex: "0E0E0C"),
            cardBackground: Color(hex: "1A1A16"),
            cardElevated:   Color(hex: "222220"),
            surfaceOverlay: Color(hex: "161614"),
            border:         Color(hex: "3A3A34"),
            borderSubtle:   Color(hex: "2A2A26"),
            textPrimary:    Color(hex: "F0EEE8"),
            textSecondary:  Color(hex: "A0A098"),
            textMuted:      Color(hex: "606058"),
            accent:         accent
        )
    }

    /// Night vision — pure black + red, preserves scotopic vision
    static func redLight() -> ThemePalette {
        ThemePalette(
            appBackground:  Color(hex: "000000"),
            cardBackground: Color(hex: "0A0000"),
            cardElevated:   Color(hex: "140000"),
            surfaceOverlay: Color(hex: "0A0000"),
            border:         Color(hex: "2A0000"),
            borderSubtle:   Color(hex: "1A0000"),
            textPrimary:    Color(hex: "CC3311"),
            textSecondary:  Color(hex: "882211"),
            textMuted:      Color(hex: "551100"),
            accent:         Color(hex: "CC3311")
        )
    }
}

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let lightingKey = "radiclebotany_lighting_mode"
    private static let autoKey     = "radiclebotany_auto_lighting"

    @Published var lightingMode: LightingMode = .night {
        didSet {
            AppColors.isRedLight = (lightingMode == .redLight)
            UserDefaults.standard.set(lightingMode.rawValue, forKey: Self.lightingKey)
            _palette = Self.resolvePalette(lightingMode)
        }
    }

    @Published var autoLighting: Bool = false {
        didSet {
            UserDefaults.standard.set(autoLighting, forKey: Self.autoKey)
        }
    }

    @Published private(set) var _palette: ThemePalette

    var palette: ThemePalette { _palette }

    /// True when Red Light mode is active — used by DesignSystem to swap accent colors
    var isRedLight: Bool { lightingMode == .redLight }

    private init() {
        let mode: LightingMode
        if let saved = UserDefaults.standard.string(forKey: Self.lightingKey),
           let m = LightingMode(rawValue: saved) {
            mode = m
        } else {
            mode = .night
        }

        let auto = UserDefaults.standard.object(forKey: Self.autoKey) as? Bool ?? false

        self.lightingMode = mode
        self.autoLighting = auto
        self._palette = Self.resolvePalette(mode)
        AppColors.isRedLight = (mode == .redLight)

        if auto {
            updateLightingForTimeOfDay()
        }
    }

    // MARK: - Palette Resolution

    private static let defaultAccent = Color(hex: "A57810")

    static func resolvePalette(_ lighting: LightingMode) -> ThemePalette {
        let accent = defaultAccent
        switch lighting {
        case .night:    return .night(accent: accent)
        case .light:    return .light(accent: accent)
        case .dawn:     return .dawn(accent: accent)
        case .dusk:     return .dusk(accent: accent)
        case .redLight: return .redLight()
        }
    }

    static func previewPalette(_ lighting: LightingMode) -> ThemePalette {
        resolvePalette(lighting)
    }

    // MARK: - Auto Lighting

    func updateLightingForTimeOfDay() {
        guard autoLighting else { return }

        let hour = Calendar.current.component(.hour, from: Date())
        let newMode: LightingMode
        switch hour {
        case 5..<7:   newMode = .dawn
        case 7..<17:  newMode = .light
        case 17..<20: newMode = .dusk
        default:      newMode = .night
        }

        if lightingMode != newMode {
            withAnimation(.easeInOut(duration: 0.6)) {
                lightingMode = newMode
            }
        }
    }

    func setLighting(_ mode: LightingMode) {
        withAnimation(.easeInOut(duration: 0.6)) {
            lightingMode = mode
        }
    }
}
