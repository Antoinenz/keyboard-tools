#!/usr/bin/env swift
// Generates Feeder/Assets.xcassets/AppIcon.appiconset. Run from the repo root:
//   swift scripts/make-icon.swift
import AppKit

let outDir = "Feeder/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: the squircle fills 824/1024 of the canvas.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

    // Soft drop shadow under the squircle.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    path.fill()
    ctx.restoreGState()

    // Gradient fill.
    ctx.saveGState()
    path.addClip()
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.13, green: 0.58, blue: 0.98, alpha: 1),
    ])!
    gradient.draw(in: body, angle: -60)
    // Top sheen.
    let sheen = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    sheen.draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
    ctx.restoreGState()

    // White keyboard glyph, centered.
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.46, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let glyph = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let g = glyph.size
        let rect = CGRect(x: (s - g.width) / 2, y: (s - g.height) / 2 - s * 0.01, width: g.width, height: g.height)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.02,
                      color: NSColor.black.withAlphaComponent(0.25).cgColor)
        glyph.draw(in: rect)
        ctx.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

struct Entry { let size: Int; let scale: Int }
let entries = [16, 32, 128, 256, 512].flatMap { [Entry(size: $0, scale: 1), Entry(size: $0, scale: 2)] }
var images: [[String: String]] = []
for e in entries {
    let name = "icon_\(e.size)x\(e.size)@\(e.scale)x.png"
    try render(pixels: e.size * e.scale).write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    images.append(["idiom": "mac", "size": "\(e.size)x\(e.size)", "scale": "\(e.scale)x", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: "\(outDir)/Contents.json"))
try """
{ "info" : { "version" : 1, "author" : "xcode" } }
""".write(toFile: "Feeder/Assets.xcassets/Contents.json", atomically: true, encoding: .utf8)
print("wrote \(entries.count) icons")
