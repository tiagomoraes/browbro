import AppKit
import SwiftUI

// MARK: - BrowBro design tokens
// Swift port of the BrowBro Design System (`tokens/*.css`): quiet native
// neutrals, one "BrowBro Blue" accent, adaptive light + dark. Chrome profile
// colors are external content and only ever fill a bounded avatar swatch.

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

private func adaptive(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    })
}

private func adaptive(light: UInt32, dark: UInt32) -> Color {
    adaptive(light: NSColor(hex: light), dark: NSColor(hex: dark))
}

enum BB {

    // MARK: Accent — "BrowBro Blue"

    static let accent = adaptive(light: 0x2C6BED, dark: 0x6699F5)
    static let accentHover = adaptive(light: 0x2359CE, dark: 0x85AFF8)
    static let accentActive = adaptive(light: 0x1E4FB5, dark: 0x5A8CEF)
    static let accentWeak = adaptive(light: NSColor(hex: 0xE8F0FE),
                                     dark: NSColor(hex: 0x6699F5, alpha: 0.18))
    /// Solid selection fill (macOS menu style) — the same blue in both themes.
    static let accentFill = adaptive(light: 0x2C6BED, dark: 0x2C6BED)
    static let onAccent = Color.white

    // MARK: Surfaces

    static let surfaceRaised = adaptive(light: 0xFFFFFF, dark: 0x2E2E31)
    static let surfaceSunken = adaptive(light: 0xEDEDF0, dark: 0x202022)
    /// Solid fallback for the popover surface (the real one is vibrancy).
    static let surfacePopoverSolid = adaptive(light: 0xF6F6F8, dark: 0x262629)

    // MARK: Fills (row states, controls)

    static let fillHover = adaptive(light: NSColor(hex: 0x000000, alpha: 0.055),
                                    dark: NSColor(hex: 0xFFFFFF, alpha: 0.08))
    static let fillPressed = adaptive(light: NSColor(hex: 0x000000, alpha: 0.09),
                                      dark: NSColor(hex: 0xFFFFFF, alpha: 0.12))
    static let fillQuiet = adaptive(light: NSColor(hex: 0x000000, alpha: 0.045),
                                    dark: NSColor(hex: 0xFFFFFF, alpha: 0.07))

    // MARK: Lines

    static let separator = adaptive(light: NSColor(hex: 0x000000, alpha: 0.10),
                                    dark: NSColor(hex: 0xFFFFFF, alpha: 0.12))
    static let borderHairline = adaptive(light: NSColor(hex: 0x000000, alpha: 0.12),
                                         dark: NSColor(hex: 0xFFFFFF, alpha: 0.14))
    /// Outer ring around floating surfaces (part of --shadow-popover).
    static let popoverRing = adaptive(light: NSColor(hex: 0x000000, alpha: 0.12),
                                      dark: NSColor(hex: 0xFFFFFF, alpha: 0.10))

    // MARK: Text

    static let textPrimary = adaptive(light: 0x1D1D1F, dark: 0xF5F5F7)
    static let textSecondary = adaptive(light: 0x6E6E73, dark: 0xA1A1A6)
    static let textTertiary = adaptive(light: 0x98989D, dark: 0x7C7C82)
    static let textQuaternary = adaptive(light: 0xB8B8BD, dark: 0x5A5A60)

    // MARK: Icons

    static let iconPrimary = adaptive(light: 0x3A3A3C, dark: 0xE5E5EA)
    static let iconSecondary = adaptive(light: 0x8E8E93, dark: 0x98989D)

    // MARK: Semantic status (used sparingly — a utility stays quiet)

    static let success = adaptive(light: 0x248A3D, dark: 0x30D158)
    static let warning = adaptive(light: 0xB25000, dark: 0xFF9F0A)
    static let danger = adaptive(light: 0xD70015, dark: 0xFF453A)

    // MARK: Shape

    static let radiusXS: CGFloat = 4     // keycaps, micro badges
    static let radiusSM: CGFloat = 6     // rows, small buttons
    static let radiusMD: CGFloat = 8     // buttons, chips, inputs
    static let radiusLG: CGFloat = 12    // popover, cards
    static let radiusXL: CGFloat = 16    // large panels, onboarding sheet
    static let hairline: CGFloat = 0.5

    // MARK: Spacing (compact ladder; matches the prototype's 14pt inset rhythm)

    static let padRowX: CGFloat = 6
    static let padRowY: CGFloat = 4
    static let padPopover: CGFloat = 4
    static let padPanel: CGFloat = 14
    static let gapRow: CGFloat = 2
}

// MARK: - Typography (system font is the design system's native face;
// mono is reserved for URLs)

enum BBFont {
    static let row = Font.system(size: 13, weight: .medium)
    static let rowSub = Font.system(size: 12)
    static let label = Font.system(size: 11, weight: .semibold)
    static let caption = Font.system(size: 11)
    static let body = Font.system(size: 14)
    static let title = Font.system(size: 17, weight: .semibold)
    static let headline = Font.system(size: 24, weight: .semibold)
    static let url = Font.system(size: 12, weight: .medium, design: .monospaced)

    /// Small-caps group labels track +0.04em.
    static let labelTracking: CGFloat = 11 * 0.04
}

// MARK: - Motion (quiet and quick, never bouncy)

enum BBMotion {
    /// cubic-bezier(0.2, 0.8, 0.2, 1)
    static func easeOut(_ duration: Double) -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1, duration: duration)
    }

    static let instant = 0.07   // selection follows the keyboard/pointer
    static let quick = 0.09     // picker dismiss
    static let fast = 0.12      // picker appear
    static let panel = 0.20     // settings / onboarding panels
}
