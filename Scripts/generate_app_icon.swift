import AppKit
import Foundation

let side = 1024
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("CineFrame/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high

let canvas = CGRect(x: 0, y: 0, width: side, height: side)
NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.095, alpha: 1).setFill()
NSBezierPath(roundedRect: canvas, xRadius: 220, yRadius: 220).fill()

let frame = CGRect(x: 166, y: 314, width: 692, height: 396)
let framePath = NSBezierPath(roundedRect: frame, xRadius: 40, yRadius: 40)
NSColor(calibratedRed: 0.17, green: 0.19, blue: 0.20, alpha: 1).setFill()
framePath.fill()
NSColor(calibratedRed: 0.80, green: 0.82, blue: 0.82, alpha: 1).setStroke()
framePath.lineWidth = 18
framePath.stroke()

let imageArea = CGRect(x: 184, y: 374, width: 656, height: 276)
NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.46, alpha: 1).setFill()
NSBezierPath(rect: imageArea).fill()

// A quiet horizon gives the center crop a photographic cue.
NSColor(calibratedRed: 0.70, green: 0.60, blue: 0.43, alpha: 1).setFill()
NSBezierPath(ovalIn: CGRect(x: 660, y: 510, width: 92, height: 92)).fill()
let landscape = NSBezierPath()
landscape.move(to: CGPoint(x: imageArea.minX, y: 420))
landscape.line(to: CGPoint(x: 352, y: 548))
landscape.line(to: CGPoint(x: 468, y: 472))
landscape.line(to: CGPoint(x: 608, y: 584))
landscape.line(to: CGPoint(x: 740, y: 486))
landscape.line(to: CGPoint(x: imageArea.maxX, y: 550))
landscape.line(to: CGPoint(x: imageArea.maxX, y: imageArea.minY))
landscape.line(to: CGPoint(x: imageArea.minX, y: imageArea.minY))
landscape.close()
NSColor(calibratedRed: 0.19, green: 0.26, blue: 0.25, alpha: 1).setFill()
landscape.fill()

// Corner crop marks reinforce the app's single-purpose framing tool.
let marks = NSBezierPath()
marks.lineWidth = 15
for (x, y, sx, sy) in [(202.0, 672.0, 1.0, -1.0), (822.0, 672.0, -1.0, -1.0),
                       (202.0, 352.0, 1.0, 1.0), (822.0, 352.0, -1.0, 1.0)] {
    marks.move(to: CGPoint(x: x, y: y + sy * 48)); marks.line(to: CGPoint(x: x, y: y))
    marks.line(to: CGPoint(x: x + sx * 48, y: y))
}
NSColor.white.setStroke()
marks.stroke()

NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: output)
