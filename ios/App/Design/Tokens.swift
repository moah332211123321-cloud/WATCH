import SwiftUI
import UIKit

/// Design tokens from replica/design/tokens.json (light) and tokens-dark.json (dark).
/// Components use these roles only — never raw colours.
enum Tok {
    static let bg = Color(light: 0xF2F2F7, dark: 0x000000)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1C1C1F)
    static let border = Color(light: 0xE2E2E8, dark: 0x2E2E33)
    static let text = Color(light: 0x111114, dark: 0xF5F5F7)
    static let textMuted = Color(light: 0x5C5C66, dark: 0xA1A1AA)
    static let accent = Color(light: 0x0B7A75, dark: 0x3FD2C7)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x00201E)
    static let danger = Color(light: 0xC2262E, dark: 0xFF6B6B)
    static let success = Color(light: 0x1B7A3E, dark: 0x4ADE80)
    static let warning = Color(light: 0x9A5B00, dark: 0xFBBF24)

    static let heart = Color(light: 0xD0203A, dark: 0xFF5A6E)
    static let oxygen = Color(light: 0x1660C9, dark: 0x5AA2FF)
    static let steps = Color(light: 0xB84A00, dark: 0xFF9A3C)
    static let sleep = Color(light: 0x5B3FC4, dark: 0xA48BFF)
    static let energy = Color(light: 0xC7254E, dark: 0xFF6B9A)
    static let stress = Color(light: 0x0A7A8A, dark: 0x40D6E0)
    static let temp = Color(light: 0xA3480F, dark: 0xFFA05A)

    enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32 }
    enum Radius { static let s: CGFloat = 8, m: CGFloat = 14, l: CGFloat = 22 }
    static let ringAnimation = Animation.easeInOut(duration: 0.8)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

/// Localized key for SwiftUI views. All user-facing literals go through `L` or `S` so
/// `ios/l10n/check.py` can verify every key has an Arabic translation.
func L(_ key: String) -> LocalizedStringKey { LocalizedStringKey(key) }
/// Localized `String` (for alerts built from errors, accessibility values…).
func S(_ key: String) -> String { String(localized: String.LocalizationValue(key)) }
