import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-bg.png"
let w: CGFloat = 540
let h: CGFloat = 320
let scale: CGFloat = 2

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(w * scale),
    pixelsHigh: Int(h * scale),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: w, height: h)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bgGrad = NSGradient(
    starting: NSColor(calibratedRed: 0.97, green: 0.975, blue: 0.985, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.91, green: 0.925, blue: 0.95, alpha: 1.0)
)!
bgGrad.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1.0),
]
let title = "XamppLocal" as NSString
let titleSize = title.size(withAttributes: titleAttrs)
title.draw(at: NSPoint(x: (w - titleSize.width) / 2, y: h - 46), withAttributes: titleAttrs)

let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.43, green: 0.45, blue: 0.50, alpha: 1.0),
]
let sub = "Drag to Applications to install" as NSString
let subSize = sub.size(withAttributes: subAttrs)
sub.draw(at: NSPoint(x: (w - subSize.width) / 2, y: h - 67), withAttributes: subAttrs)

// Centered arrow between left icon (x=145) and right Applications icon (x=395) at Finder y=155 (Cocoa y=165)
let arrowColor = NSColor(calibratedRed: 0.35, green: 0.39, blue: 0.47, alpha: 0.50)
arrowColor.setStroke()
let yMid: CGFloat = 165
let line = NSBezierPath()
line.lineWidth = 2.8
line.lineCapStyle = .round
line.move(to: NSPoint(x: 230, y: yMid))
line.line(to: NSPoint(x: 308, y: yMid))
line.stroke()

let head = NSBezierPath()
head.lineWidth = 2.8
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.move(to: NSPoint(x: 297, y: yMid + 10))
head.line(to: NSPoint(x: 310, y: yMid))
head.line(to: NSPoint(x: 297, y: yMid - 10))
head.stroke()

NSGraphicsContext.restoreGraphicsState()

if let data = rep.representation(using: .png, properties: [:]) {
    try data.write(to: URL(fileURLWithPath: outPath))
    print("Generated \(outPath)")
}
