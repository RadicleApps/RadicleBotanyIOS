import UIKit
import CoreGraphics
import CoreText

/// Registers custom fonts from the asset catalog at launch.
///
/// - `registerInter()`   — Inter 18pt (UI / body / labels)
/// - `registerCormorant()` — Cormorant Garamond (display / titles / wordmark)
///
/// Call both from `RadicleBotanyApp.init()`.
///
/// Cormorant Garamond files live at:
///     Assets.xcassets / Fonts / Cormorant / static / [weight].ttf
///     (8 static weights from fonts.google.com/specimen/Cormorant+Garamond)

enum FontRegistration {

    // MARK: - Inter

    private static let interFontAssets = [
        "Inter_18pt-Regular",
        "Inter_18pt-Medium",
        "Inter_18pt-SemiBold",
        "Inter_18pt-Bold",
        "Inter_18pt-ExtraBold",
        "Inter_18pt-Black"
    ]

    /// Loads Inter 18pt fonts from `Assets.xcassets/Fonts/Inter/attachments/`.
    /// Safe to call multiple times — skips fonts that are already registered.
    static func registerInter() {
        register(assets: interFontAssets, pathPrefix: "Fonts/Inter/attachments")
    }

    // MARK: - Cormorant Garamond

    private static let cormorantFontAssets = [
        "CormorantGaramond-Light",
        "CormorantGaramond-LightItalic",
        "CormorantGaramond-Regular",
        "CormorantGaramond-Italic",
        "CormorantGaramond-SemiBold",
        "CormorantGaramond-SemiBoldItalic",
        "CormorantGaramond-Bold",
        "CormorantGaramond-BoldItalic"
    ]

    /// Loads Cormorant Garamond fonts from `Assets.xcassets/Fonts/Cormorant/static/`.
    /// Safe to call multiple times — skips fonts that are already registered.
    /// If font files are missing, display tokens gracefully fall back to system serif.
    static func registerCormorant() {
        register(assets: cormorantFontAssets, pathPrefix: "Fonts/Cormorant/static")
    }

    // MARK: - Shared Registration

    private static func register(assets: [String], pathPrefix: String) {
        for assetName in assets {
            guard let dataAsset = NSDataAsset(name: "\(pathPrefix)/\(assetName)") else {
                print("[FontRegistration] ⚠️ Missing asset: \(pathPrefix)/\(assetName)")
                continue
            }

            guard let provider = CGDataProvider(data: dataAsset.data as CFData),
                  let cgFont = CGFont(provider) else {
                print("[FontRegistration] ⚠️ Failed to create CGFont: \(assetName)")
                continue
            }

            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(cgFont, &error) {
                let nsError = error?.takeRetainedValue() as Error? as? NSError
                let alreadyRegistered = (nsError?.code == CTFontManagerError.alreadyRegistered.rawValue)
                if !alreadyRegistered {
                    print("[FontRegistration] ⚠️ Registration failed for \(assetName): \(nsError?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
}
