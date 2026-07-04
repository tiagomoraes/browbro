#!/usr/bin/env swift
//
// Renders the BrowBro app icon (design system: assets/browbro-appicon.svg —
// white unibrow mark on a BrowBro-blue squircle) into an .iconset directory.
//
//   swift scripts/generate-appicon.swift <output.iconset>
//   iconutil -c icns <output.iconset> -o Resources/AppIcon.icns
//
import AppKit
import ImageIO
import UniformTypeIdentifiers

func srgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func render(px: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Work in the SVG's 1024-grid, y-down.
    ctx.translateBy(x: 0, y: CGFloat(px))
    ctx.scaleBy(x: CGFloat(px) / 1024, y: -CGFloat(px) / 1024)

    // Tile: rounded rect 100,100 824×824, r=184, vertical gradient.
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 184, cornerHeight: 184, transform: nil)
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space,
                              colors: [srgb(0x4D84F0), srgb(0x2C6BED), srgb(0x1E4FB5)] as CFArray,
                              locations: [0, 0.46, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 512, y: 100),
                           end: CGPoint(x: 512, y: 924), options: [])
    ctx.restoreGState()

    // Glyph group: translate(212,207) scale(25) on the 24-grid.
    ctx.saveGState()
    ctx.translateBy(x: 212, y: 207)
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

    return ctx.makeImage()!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-appicon.swift <output.iconset>\n".utf8))
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let variants: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    let url = outDir.appendingPathComponent("\(variant.name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, render(px: variant.px), nil)
    guard CGImageDestinationFinalize(dest) else {
        FileHandle.standardError.write(Data("failed to write \(url.path)\n".utf8))
        exit(1)
    }
}
print("wrote \(variants.count) sizes to \(outDir.path)")
