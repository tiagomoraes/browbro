import AppKit
import SwiftUI

// MARK: - Cursor affordances

extension View {
    /// Show a cursor while hovering — pointer on clickable things, grab on
    /// draggable ones (design: `cursor: pointer` / `cursor: grab`).
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.set() } else { NSCursor.arrow.set() }
        }
    }
}

// MARK: - Vibrancy surface
// The picker and menu float on real macOS vibrancy (design token
// --blur-popover), used only on floating system surfaces, never on cards.

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

// MARK: - Button (components/controls/Button.jsx)
// primary = accent-filled default action · secondary = quiet bordered ·
// ghost = text-only. Compact by design; press dips to scale(0.98).

struct BBButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, ghost }
    enum Size { case sm, md, lg }

    var variant: Variant = .secondary
    var size: Size = .md
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        ButtonBody(configuration: configuration, variant: variant, size: size, fullWidth: fullWidth)
    }

    private struct ButtonBody: View {
        let configuration: Configuration
        let variant: Variant
        let size: Size
        let fullWidth: Bool
        @State private var hovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed
            let metrics: (height: CGFloat, padX: CGFloat, font: CGFloat) = switch size {
            case .sm: (22, 8, 12)
            case .md: (28, 12, 14)
            case .lg: (34, 16, 15)
            }

            configuration.label
                .font(.system(size: metrics.font, weight: .medium))
                .tracking(-0.01 * metrics.font)
                .lineLimit(1)
                .padding(.horizontal, metrics.padX)
                .frame(height: metrics.height)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .foregroundStyle(foreground)
                .background(background(pressed: pressed), in: RoundedRectangle(cornerRadius: BB.radiusMD, style: .continuous))
                .overlay {
                    if variant == .secondary {
                        RoundedRectangle(cornerRadius: BB.radiusMD, style: .continuous)
                            .strokeBorder(BB.borderHairline, lineWidth: BB.hairline)
                    }
                }
                .shadow(color: variant == .ghost ? .clear : .black.opacity(0.10), radius: 1, x: 0, y: 1)
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(pressed ? 0.98 : 1)
                .animation(BBMotion.easeOut(BBMotion.instant), value: pressed)
                .animation(BBMotion.easeOut(BBMotion.instant), value: hovered)
                .onHover { inside in
                    hovered = inside
                    if isEnabled {
                        (inside ? NSCursor.pointingHand : NSCursor.arrow).set()
                    }
                }
        }

        private var foreground: Color {
            switch variant {
            case .primary: BB.onAccent
            case .secondary: BB.textPrimary
            case .ghost: BB.accent
            }
        }

        private func background(pressed: Bool) -> Color {
            switch variant {
            case .primary: pressed ? BB.accentActive : hovered ? BB.accentHover : BB.accentFill
            case .secondary: pressed ? BB.fillPressed : hovered ? BB.fillHover : BB.surfaceRaised
            case .ghost: pressed ? BB.fillPressed : hovered ? BB.fillHover : .clear
            }
        }
    }
}

// MARK: - Switch (components/controls/Switch.jsx)
// The macOS toggle for Settings: accent fill when on, sliding white knob.
// Custom so the on-state is BrowBro Blue, not the system accent.

struct BBSwitch: View {
    @Binding var isOn: Bool
    var size: Size = .md

    enum Size { case sm, md }

    var body: some View {
        let dims: (w: CGFloat, h: CGFloat, knob: CGFloat) = size == .sm ? (30, 18, 14) : (38, 22, 18)
        let pad = (dims.h - dims.knob) / 2

        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? BB.accentFill : BB.fillPressed)
                    .overlay {
                        if !isOn {
                            Capsule().strokeBorder(BB.borderHairline, lineWidth: BB.hairline)
                        }
                    }
                Circle()
                    .fill(.white)
                    .frame(width: dims.knob, height: dims.knob)
                    .shadow(color: .black.opacity(0.28), radius: 1.5, x: 0, y: 1)
                    .padding(pad)
            }
            .frame(width: dims.w, height: dims.h)
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .animation(BBMotion.easeOut(BBMotion.fast), value: isOn)
    }
}

// MARK: - Status pill (MenuDropdown.jsx)

struct StatusPill: View {
    let ok: Bool
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(ok ? BB.success : BB.warning).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(BB.textSecondary)
        .padding(.leading, 7)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(BB.fillQuiet, in: Capsule())
    }
}

// MARK: - KeyCap (components/picker/KeyCap.jsx)
// The keyboard quick-key badge. Quiet by default; on a selected (accent-filled)
// row it reads as a translucent white chip.

struct KeyCap: View {
    let text: String
    var onAccent = false

    var body: some View {
        Text(text)
            .font(BBFont.label)
            .tracking(0.01 * 11)
            .monospacedDigit()
            .foregroundStyle(onAccent ? .white : BB.textSecondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 19)
            .frame(height: 19)
            .background(
                onAccent ? Color.white.opacity(0.22) : BB.fillQuiet,
                in: RoundedRectangle(cornerRadius: BB.radiusXS, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BB.radiusXS, style: .continuous)
                    .strokeBorder(onAccent ? Color.white.opacity(0.28) : BB.borderHairline,
                                  lineWidth: BB.hairline))
    }
}

// MARK: - ProfileSwatch (components/picker/ProfileSwatch.jsx)
// Chrome profile avatar: the profile's highlight color bounded in a circle
// with the profile initial, never used as UI accent.

struct ProfileSwatch: View {
    let name: String
    let colorARGB: Int?
    var size: CGFloat = 26

    var body: some View {
        let fill = color
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: BB.hairline))
            .overlay(
                Text(initialLetter)
                    .font(.system(size: (size * 0.44).rounded(), weight: .semibold))
                    .foregroundStyle(ink))
            .accessibilityLabel("\(name) profile")
    }

    private var initialLetter: String {
        let first = name.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? "•"
        return first.uppercased()
    }

    private var color: Color {
        guard let argb = colorARGB else { return Color(red: 0x5F / 255, green: 0x63 / 255, blue: 0x68 / 255) }
        return Color(red: Double((argb >> 16) & 0xFF) / 255,
                     green: Double((argb >> 8) & 0xFF) / 255,
                     blue: Double(argb & 0xFF) / 255)
    }

    /// Black/white initial by background luminance, mirroring the DS formula.
    private var ink: Color {
        guard let argb = colorARGB else { return .white }
        let r = Double((argb >> 16) & 0xFF), g = Double((argb >> 8) & 0xFF), b = Double(argb & 0xFF)
        let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return luminance > 0.6 ? .black.opacity(0.82) : .white
    }
}

// MARK: - App icon chip (components/picker/BrowserIcon.jsx)
// At runtime BrowBro always shows the app's real macOS icon from NSWorkspace.

struct AppIconChip: View {
    let appURL: URL
    var size: CGFloat = 26

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

// MARK: - Private Window badge
// Corner badge over a target's icon or swatch: a privacy pick must be
// unmistakable at a glance, in the picker and in Settings alike.

struct PrivateBadge: View {
    var size: CGFloat = 13

    var body: some View {
        Circle()
            .fill(Color(white: 0.16))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "sunglasses.fill")
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white))
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: BB.hairline))
            .accessibilityLabel("Private window")
    }
}

// MARK: - Hairline divider

struct BBDivider: View {
    var inset: CGFloat = 0

    var body: some View {
        BB.separator
            .frame(height: BB.hairline)
            .padding(.horizontal, inset)
    }
}

// MARK: - Small-caps section label (GroupHeader / menu Label)

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(BBFont.label)
            .tracking(BBFont.labelTracking)
            .foregroundStyle(BB.textTertiary)
    }
}
