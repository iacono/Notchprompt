#!/usr/bin/env swift
import Cocoa

func createAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
        let pad = size * 0.08
        let bgRect = rect.insetBy(dx: pad, dy: pad)

        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.18, yRadius: size * 0.18)
        let gradient = NSGradient(
            starting: NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1),
            ending: NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
        )
        gradient?.draw(in: bgPath, angle: -90)

        let lw: CGFloat = size * 0.02
        let cx = size / 2

        let sw: CGFloat = size * 0.52
        let sh: CGFloat = size * 0.34
        let screenY = size * 0.18
        let screenRect = NSRect(x: cx - sw / 2, y: screenY, width: sw, height: sh)
        let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: size * 0.025, yRadius: size * 0.025)
        NSColor.white.setStroke()
        screenPath.lineWidth = lw * 2.0
        screenPath.stroke()

        let neckTop = screenRect.maxY
        let neckBot = neckTop + size * 0.08
        let neckPath = NSBezierPath()
        neckPath.move(to: NSPoint(x: cx, y: neckTop))
        neckPath.line(to: NSPoint(x: cx, y: neckBot))
        neckPath.lineWidth = lw * 2.0
        neckPath.stroke()

        let baseW: CGFloat = size * 0.26
        let basePath = NSBezierPath()
        basePath.move(to: NSPoint(x: cx - baseW / 2, y: neckBot))
        basePath.line(to: NSPoint(x: cx + baseW / 2, y: neckBot))
        basePath.lineWidth = lw * 2.5
        basePath.lineCapStyle = .round
        basePath.stroke()

        let linesData: [(yFrac: CGFloat, wFrac: CGFloat)] = [
            (0.28, 0.8),
            (0.50, 0.6),
            (0.72, 0.4),
        ]
        let innerW = sw - size * 0.08
        NSColor(white: 0.55, alpha: 1).setStroke()
        for line in linesData {
            let y = screenRect.minY + sh * line.yFrac
            let w = innerW * line.wFrac
            let p = NSBezierPath()
            p.move(to: NSPoint(x: cx - w / 2, y: y))
            p.line(to: NSPoint(x: cx + w / 2, y: y))
            p.lineWidth = lw * 1.8
            p.lineCapStyle = .round
            p.stroke()
        }

        return true
    }
    return image
}

func savePNG(_ image: NSImage, to path: String, pixelSize: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path) (\(pixelSize)x\(pixelSize))")
}

// Generate icons
let icon = createAppIcon(size: 1024)
let outputDir = "NotchPrompter/Resources"

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for size in sizes {
    savePNG(icon, to: "\(outputDir)/\(size.name).png", pixelSize: size.pixels)
}

print("Done! Now create an .icns with: iconutil -c icns \(outputDir)/AppIcon.iconset")
