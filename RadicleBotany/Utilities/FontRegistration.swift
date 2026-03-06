import UIKit
import CoreGraphics
import CoreText

/// Registers Inter 18pt static fonts from the asset catalog at launch.
/// Only the 6 weights used by AppTypography are loaded.
///
/// Call `FontRegistration.registerInter()` from `RadicleBotanyApp.init()`.

enum FontRegistration {

    /// Asset catalog dataset names → PostScript font names after registration.
    private static let fontAssets = [
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
        for assetName in fontAssets {
            guard let dataAsset = NSDataAsset(name: "Fonts/Inter/attachments/\(assetName)") else {
                print("[FontRegistration] ⚠️ Missing asset: \(assetName)")
                continue
            }

            guard let provider = CGDataProvider(data: dataAsset.data as CFData),
                  let cgFont = CGFont(provider) else {
                print("[FontRegistration] ⚠️ Failed to create CGFont: \(assetName)")
                continue
            }

            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(cgFont, &error) {
                // kCTFontManagerErrorAlreadyRegistered is fine — means we already loaded it
                let nsError = error?.takeRetainedValue() as Error? as? NSError
                let alreadyRegistered = (nsError?.code == CTFontManagerError.alreadyRegistered.rawValue)
                if !alreadyRegistered {
                    print("[FontRegistration] ⚠️ Registration failed for \(assetName): \(nsError?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
}
