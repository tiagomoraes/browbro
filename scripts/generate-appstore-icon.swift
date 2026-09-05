#!/usr/bin/env swift
//
// 1024×1024 App Store Connect icon: full-bleed square, no alpha, no squircle.
// Apple applies the macOS mask. The Dock .icns (scripts/generate-appicon.swift)
// stays the in-app squircle; this file is only for the store listing.
//
//   swift scripts/generate-appstore-icon.swift packaging/mas/AppStoreIcon.png
//
import AppKit
import ImageIO
import UniformTypeIdentifiers

func srgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-appstore-icon.swift <out.png>\n".utf8))
    exit(1)
}

let px = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
// No alpha — App Store Connect rejects transparency on the 1024 icon.
let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                    bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

ctx.translateBy(x: 0, y: CGFloat(px))
ctx.scaleBy(x: CGFloat(px) / 1024, y: -CGFloat(px) / 1024)

let gradient = CGGradient(colorsSpace: space,
                          colors: [srgb(0x4D84F0), srgb(0x2C6BED), srgb(0x1E4FB5)] as CFArray,
                          locations: [0, 0.46, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 512, y: 0),
                       end: CGPoint(x: 512, y: 1024), options: [])

// Same glyph as the Dock icon, recentered on the full canvas.
// Dock icon: translate(212,207) scale(25) on an 824-pt tile inset by 100.
// Full-bleed: scale so the 24-grid mark sits at ~62% of the canvas.
ctx.saveGState()
let mark = 24.0 * 25.0          // 600 pt on the 1024 grid (Dock)
let origin = (1024.0 - mark) / 2
ctx.translateBy(x: origin, y: origin)
ctx.scaleBy(x: 25, y: 25)

let brow = CGMutablePath()
brow.move(to: CGPoint(x: 3.5, y: 13))
brow.addCurve(to: CGPoint(x: 10.6, y: 11),
              control1: CGPoint(x: 5, y: 8), control2: CGPoint(x: 9, y: 8))
brow.addCurve(to: CGPoint(x: 13.4, y: 11),
              control1: CGPoint(x: 11.3, y: 12.3), control2: CGPoint(x: 12.7, y: 12.3))
brow.addCurve(to: CGPoint(x: 20.5, y: 13),
              control1: CGPoint(x: 15, y: 8), control2: CGPoint(x: 19, y: 8))
ctx.addPath(brow)
ctx.setStrokeColor(.white)
ctx.setLineWidth(3.6)
ctx.setLineCap(.round)
ctx.strokePath()

ctx.setFillColor(.white)
for x in [7.3, 16.7] {
    ctx.fillEllipse(in: CGRect(x: x - 1.75, y: 16.8 - 1.75, width: 3.5, height: 3.5))
}
ctx.restoreGState()

let image = ctx.makeImage()!
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, [
    kCGImagePropertyDPIWidth: 72,
    kCGImagePropertyDPIHeight: 72,
] as CFDictionary)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("failed to write \(out.path)\n".utf8))
    exit(1)
}
print("wrote \(out.path)")
