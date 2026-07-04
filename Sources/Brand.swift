import AppKit
import SwiftUI

// MARK: - BrowBro brand mark
// The logomark is a minimalist "unibrow": one continuous arched brow over two
// dot eyes — a wink at the "brow" in BrowBro. Single-color, so it doubles as a
// macOS template image at 16px and scales to the 1024px app icon.
// Geometry mirrors assets/browbro-mark.svg exactly (24×24 grid).

/// The brow stroke, on a 24×24 design grid scaled to `rect`.
struct BrowStrokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        p.move(to: CGPoint(x: 3.5 * s, y: 13 * s))
        p.addCurve(to: CGPoint(x: 10.6 * s, y: 11 * s),
                   control1: CGPoint(x: 5 * s, y: 8 * s),
                   control2: CGPoint(x: 9 * s, y: 8 * s))
        p.addCurve(to: CGPoint(x: 13.4 * s, y: 11 * s),
                   control1: CGPoint(x: 11.3 * s, y: 12.3 * s),
                   control2: CGPoint(x: 12.7 * s, y: 12.3 * s))
        p.addCurve(to: CGPoint(x: 20.5 * s, y: 13 * s),
                   control1: CGPoint(x: 15 * s, y: 8 * s),
                   control2: CGPoint(x: 19 * s, y: 8 * s))
        return p
    }
}

struct LogomarkView: View {
    var size: CGFloat = 24
    var color: Color = .primary
    var strokeWidth: CGFloat = 3.4   // on the 24-grid

    var body: some View {
        let s = size / 24
        ZStack(alignment: .topLeading) {
            BrowStrokeShape()
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth * s, lineCap: .round))
            eye.position(x: 7.3 * s, y: 16.8 * s)
            eye.position(x: 16.7 * s, y: 16.8 * s)
        }
        .frame(width: size, height: size)
    }

    private var eye: some View {
        Circle().fill(color).frame(width: 3.5 * size / 24, height: 3.5 * size / 24)
    }
}

/// The "BrowBro" lockup: bold, tight tracking; the mark carries the accent.
struct WordmarkView: View {
    var size: CGFloat = 28
    var showMark = true
    var color: Color = BB.textPrimary
    var markColor: Color = BB.accent

    var body: some View {
        HStack(spacing: (size * 0.42).rounded()) {
            if showMark {
                LogomarkView(size: (size * 1.16).rounded(), color: markColor)
            }
            Text("BrowBro")
                .font(.system(size: size, weight: .bold))
                .tracking(-0.02 * size)
                .foregroundStyle(color)
        }
    }
}

/// The macOS app-icon tile (accent variant): white mark on a BrowBro-blue
/// squircle. Used in onboarding; the bundled .icns is rendered from the same
/// geometry.
struct AppIconView: View {
    var size: CGFloat = 128

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
            .fill(LinearGradient(
                stops: [
                    .init(color: Color(red: 0x4D / 255, green: 0x84 / 255, blue: 0xF0 / 255), location: 0),
                    .init(color: Color(red: 0x2C / 255, green: 0x6B / 255, blue: 0xED / 255), location: 0.46),
                    .init(color: Color(red: 0x1E / 255, green: 0x4F / 255, blue: 0xB5 / 255), location: 1),
                ],
                startPoint: .top, endPoint: .bottom))
            .overlay(LogomarkView(size: (size * 0.62).rounded(), color: .white, strokeWidth: 3.6))
            .frame(width: size, height: size)
            // Shadow scales with the tile so tiny inline icons stay crisp.
            .shadow(color: .black.opacity(0.32), radius: size * 0.14, x: 0, y: size * 0.11)
    }
}

// MARK: - Menu-bar status item glyph

enum BBBrand {
    /// The menu-bar glyph as a monochrome template image, so macOS tints it to
    /// match the menu bar and inverts it while the menu is open.
    static func menuBarIcon(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let s = rect.width / 24

            let brow = NSBezierPath()
            brow.move(to: NSPoint(x: 3.5 * s, y: 13 * s))
            brow.curve(to: NSPoint(x: 10.6 * s, y: 11 * s),
                       controlPoint1: NSPoint(x: 5 * s, y: 8 * s),
                       controlPoint2: NSPoint(x: 9 * s, y: 8 * s))
            brow.curve(to: NSPoint(x: 13.4 * s, y: 11 * s),
                       controlPoint1: NSPoint(x: 11.3 * s, y: 12.3 * s),
                       controlPoint2: NSPoint(x: 12.7 * s, y: 12.3 * s))
            brow.curve(to: NSPoint(x: 20.5 * s, y: 13 * s),
                       controlPoint1: NSPoint(x: 15 * s, y: 8 * s),
                       controlPoint2: NSPoint(x: 19 * s, y: 8 * s))
            brow.lineWidth = 3.4 * s
            brow.lineCapStyle = .round
            NSColor.black.setStroke()
            brow.stroke()

            NSColor.black.setFill()
            for x in [7.3, 16.7] {
                NSBezierPath(ovalIn: NSRect(x: (x - 1.75) * s, y: (16.8 - 1.75) * s,
                                            width: 3.5 * s, height: 3.5 * s)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
