import SwiftUI
import UIKit

/// Contour design tokens (docs/design/brickline-design.md section 2).
/// Ink tokens color symbols, words and targets. Fill tokens color Profile blocks and strokes only, never text.
enum BL {
    // Surfaces
    static let background = dynamic(0xF4F2EC, 0x121214)
    static let surface = dynamic(0xFFFFFF, 0x1C1C1F)
    static let surfaceElevated = dynamic(0xFFFFFF, 0x27272B)
    static let separator = dynamic(0xD9D6CE, 0x2E2E33, highContrastLight: 0x7F7B74, highContrastDark: 0x7A7A82)

    // Text and accent (accent is ink, never blue)
    static let textPrimary = dynamic(0x1B1C1F, 0xF2F0EA)
    static let textSecondary = dynamic(0x5B5E66, 0x9D9B94, highContrastLight: 0x1B1C1F, highContrastDark: 0xF2F0EA)
    static let accent = dynamic(0x1B1C1F, 0xF2F0EA)
    static let onAccent = dynamic(0xF2F0EA, 0x1B1C1F)

    // Sport
    static let swimInk = dynamic(0x1A6698, 0x8FC6F0)
    static let swimFill = dynamic(0x2E86C4, 0x4FA3E0)
    static let bikeInk = dynamic(0x8A5A00, 0xF2C25C)
    static let bikeFill = dynamic(0xA8760A, 0xD9A030)
    static let runInk = dynamic(0x1B1C1F, 0xF2F0EA)
    static let runFill = dynamic(0x2B2D32, 0xE2DFD8)

    // Status (warning is text only)
    static let success = dynamic(0x246B42, 0x6FC792)
    static let warning = dynamic(0x9E4612, 0xF0A548)
    static let destructive = dynamic(0xB8342A, 0xF2736A)

    // The player is always true black and always uses the dark tokens.
    static let playerBackground = Color.black
    enum Player {
        static let textPrimary = Color(uiColor: UIColor(hex: 0xF2F0EA))
        static let textSecondary = Color(uiColor: UIColor(hex: 0x9D9B94))
        static let accent = Color(uiColor: UIColor(hex: 0xF2F0EA))
        static let onAccent = Color(uiColor: UIColor(hex: 0x1B1C1F))
        static let plate = Color(uiColor: UIColor(hex: 0x27272B))
        static let swimFill = Color(uiColor: UIColor(hex: 0x4FA3E0))
        static let bikeFill = Color(uiColor: UIColor(hex: 0xD9A030))
        static let runFill = Color(uiColor: UIColor(hex: 0xE2DFD8))
        static let swimInk = Color(uiColor: UIColor(hex: 0x8FC6F0))
        static let bikeInk = Color(uiColor: UIColor(hex: 0xF2C25C))
        static let runInk = Color(uiColor: UIColor(hex: 0xF2F0EA))
    }

    // Spacing, radii
    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32, xxxl: CGFloat = 48
        static let gutter: CGFloat = 20
        static let cardPadding: CGFloat = 16
        static let cardGap: CGFloat = 12
        static let sectionGap: CGFloat = 24
    }
    enum Radius {
        static let card: CGFloat = 14, chip: CGFloat = 8, button: CGFloat = 8, sheet: CGFloat = 28, block: CGFloat = 2, plate: CGFloat = 20
    }

    /// Card edge width: hairline normally, 1 pt under Increase Contrast (spec section 6).
    static func edgeWidth(_ contrast: ColorSchemeContrast) -> CGFloat {
        contrast == .increased ? 1 : 0.5
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let high = traits.accessibilityContrast == .high
            if high, isDark, let hc = highContrastDark { return UIColor(hex: hc) }
            if high, !isDark, let hc = highContrastLight { return UIColor(hex: hc) }
            return UIColor(hex: isDark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Typography (section 3): SF Pro text styles only; expanded width is reserved for countdowns.
enum BLFont {
    static let sessionName = Font.title2.weight(.semibold)
    static let purpose = Font.title3
    static let largeValue = Font.title.weight(.semibold).monospacedDigit()
    static let readoutValue = Font.title3.weight(.semibold).monospacedDigit()
    static let rowNumeral = Font.body.weight(.medium).monospacedDigit()
    static let label = Font.footnote.weight(.semibold).lowercaseSmallCaps()
    /// Units keep their case: m is meters, M is not. Small caps are for labels and words only.
    static let unit = Font.footnote.weight(.semibold)
    static let meta = Font.subheadline
    static let arcCountdown = Font.title.weight(.semibold).width(.expanded).monospacedDigit()
    static let labMono = Font.footnote.monospaced()
    static func hero(_ size: CGFloat) -> Font { Font.system(size: size, weight: .semibold).width(.expanded).monospacedDigit() }
}

/// Card surface: solid. Light cards get a hairline; dark cards rely on being lighter than the background,
/// except under Increase Contrast, where every card gets a 1 pt separatorHC edge.
/// `radius` and `padded` let the week strip and the watch card share the same rule.
struct CardBackground: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    var radius: CGFloat = BL.Radius.card
    var padded: Bool = true
    func body(content: Content) -> some View {
        content
            .padding(padded ? BL.Space.cardPadding : 0)
            .background(BL.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if scheme == .light || contrast == .increased {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(BL.separator, lineWidth: BL.edgeWidth(contrast))
                }
            }
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
    /// Card surface without the default padding, for components that pad themselves.
    func cardSurface(radius: CGFloat = BL.Radius.card) -> some View { modifier(CardBackground(radius: radius, padded: false)) }
}

/// Motion that respects Reduce Motion (section 7).
struct Motion {
    let reduce: Bool
    func animation(_ a: Animation) -> Animation? { reduce ? nil : a }
}

extension View {
    /// Scrolled content ends hard at the floating tab bar instead of ghosting through its glass.
    @ViewBuilder func bottomEdgeSolid() -> some View {
        if #available(iOS 26, *) { self.scrollEdgeEffectStyle(.hard, for: .bottom) } else { self }
    }
}
