#!/usr/bin/env swift
// Composite raw window captures onto 2560×1600 (16:10) App Store screenshots.
// Usage: compose-screenshots.swift <raw-dir> <out-dir>
import AppKit
import ImageIO
import UniformTypeIdentifiers

let W = 2560, H = 1600
let bgTop = NSColor(srgbRed: 0.91, green: 0.93, blue: 0.97, alpha: 1)
let bgBot = NSColor(srgbRed: 0.82, green: 0.86, blue: 0.94, alpha: 1)
let ink = NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
let mute = NSColor(srgbRed: 0.431, green: 0.431, blue: 0.451, alpha: 1)
let accent = NSColor(srgbRed: 0.173, green: 0.420, blue: 0.929, alpha: 1)

struct Shot {
    let file: String
    let kicker: String
    let title: String
    let out: String
}

let shots: [Shot] = [
    Shot(file: "picker.png",
         kicker: "THE PICKER",
         title: "Click a link. Pick a browser.",
         out: "01-picker.png"),
    Shot(file: "settings.png",
         kicker: "YOUR CATALOG",
         title: "Every installed browser, in your order.",
         out: "02-settings.png"),
    Shot(file: "onboarding.png",
         kicker: "TRUST",
         title: "Default browser, reversible any time.",
         out: "03-onboarding.png"),
]

guard CommandLine.arguments.count == 3 else {
    fputs("usage: compose-screenshots.swift <raw-dir> <out-dir>\n", stderr)
    exit(1)
}
let rawDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outDir = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func load(_ url: URL) -> NSImage? {
    guard let img = NSImage(contentsOf: url), img.size.width > 1 else { return nil }
    return img
}

func drawBackground(_ ctx: CGContext) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: space,
                          colors: [bgTop.cgColor, bgBot.cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: 0, y: 0), options: [])
}

func drawCaption(kicker: String, title: String) {
    let kickerFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
    let titleFont = NSFont.systemFont(ofSize: 48, weight: .bold)
    let kickerAttr: [NSAttributedString.Key: Any] = [
        .font: kickerFont,
        .foregroundColor: accent,
        .kern: 1.6,
    ]
    let titleAttr: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: ink,
        .kern: -0.6,
    ]
    let kickerStr = NSAttributedString(string: kicker, attributes: kickerAttr)
    let titleStr = NSAttributedString(string: title, attributes: titleAttr)
    kickerStr.draw(at: CGPoint(x: 120, y: CGFloat(H) - 110))
    titleStr.draw(at: CGPoint(x: 120, y: CGFloat(H) - 172))
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

for shot in shots {
    let raw = rawDir.appendingPathComponent(shot.file)
    guard let window = load(raw) else {
        fputs("skip \(shot.file) (missing)\n", stderr)
        continue
    }

    let canvas = NSImage(size: NSSize(width: W, height: H))
    canvas.lockFocus()
    if let ctx = NSGraphicsContext.current?.cgContext {
        drawBackground(ctx)
    }

    drawCaption(kicker: shot.kicker, title: shot.title)

    // Scale the window to sit in the lower two-thirds.
    let maxW = CGFloat(W) * (shot.file == "picker.png" ? 0.52 : 0.62)
    let maxH = CGFloat(H) * 0.64
    let src = window.size
    let scale = min(maxW / src.width, maxH / src.height, 2.6)
    let dw = src.width * scale
    let dh = src.height * scale
    let dx = (CGFloat(W) - dw) / 2
    let dy: CGFloat = 90
    window.draw(in: NSRect(x: dx, y: dy, width: dw, height: dh),
                from: .zero, operation: .sourceOver, fraction: 1)

    canvas.unlockFocus()

    var rect = NSRect(x: 0, y: 0, width: W, height: H)
    guard let cg = canvas.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        fputs("failed to rasterize \(shot.out)\n", stderr)
        continue
    }
    // Flatten to no-alpha by drawing onto an RGB context.
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let flat = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                         bytesPerRow: 0, space: space,
                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    flat.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    let out = outDir.appendingPathComponent(shot.out)
    writePNG(flat.makeImage()!, to: out)
    print("wrote \(out.path)")
}
