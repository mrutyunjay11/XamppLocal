import AppKit
import QuartzCore

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconsetDir = (outDir as NSString).appendingPathComponent("AppIcon.iconset")
let masterPng = (outDir as NSString).appendingPathComponent("AppIcon-1024.png")

let size: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("Context error") }
NSGraphicsContext.current = nsCtx
let ctx = nsCtx.cgContext
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

// Root layer
let root = CALayer()
root.frame = CGRect(x: 0, y: 0, width: size, height: size)
root.backgroundColor = NSColor.clear.cgColor

// Subtle outer macOS icon drop shadow
let shadowContainer = CALayer()
shadowContainer.frame = CGRect(x: 100, y: 100, width: 824, height: 824)
shadowContainer.shadowColor = NSColor.black.cgColor
shadowContainer.shadowOpacity = 0.42
shadowContainer.shadowOffset = CGSize(width: 0, height: -18)
shadowContainer.shadowRadius = 26

// Continuous Apple squircle tile
let tile = CAGradientLayer()
tile.frame = shadowContainer.bounds
tile.cornerRadius = 185
tile.cornerCurve = .continuous
tile.masksToBounds = true
tile.colors = [
    NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.14, alpha: 1.0).cgColor, // bottom
    NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.22, alpha: 1.0).cgColor, // mid
    NSColor(calibratedRed: 0.23, green: 0.25, blue: 0.30, alpha: 1.0).cgColor, // top
]
tile.locations = [0.0, 0.55, 1.0]
tile.startPoint = CGPoint(x: 0.5, y: 0.0)
tile.endPoint = CGPoint(x: 0.5, y: 1.0)
shadowContainer.addSublayer(tile)
root.addSublayer(shadowContainer)

// Subtle warm orange ambient backlight behind emblem
let glowLayer = CAGradientLayer()
glowLayer.type = .radial
glowLayer.frame = tile.bounds
glowLayer.colors = [
    NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.16, alpha: 0.22).cgColor,
    NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.16, alpha: 0.0).cgColor,
]
glowLayer.startPoint = CGPoint(x: 0.5, y: 0.48)
glowLayer.endPoint = CGPoint(x: 0.95, y: 0.95)
tile.addSublayer(glowLayer)

// Inner specular glass border rim
let rim = CALayer()
rim.frame = tile.bounds.insetBy(dx: 2, dy: 2)
rim.cornerRadius = 183
rim.cornerCurve = .continuous
rim.borderWidth = 3
rim.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.14).cgColor
tile.addSublayer(rim)

// Three floating Apple-style anodized server blades (bottom -> top in CG coordinates)
let bladeWidth: CGFloat = 520
let bladeHeight: CGFloat = 122
let bladeX: CGFloat = (824 - bladeWidth) / 2
let bladeYs: [CGFloat] = [196, 351, 506] // bottom (DB), mid (PHP), top (Apache)

let ledColors: [NSColor] = [
    NSColor(calibratedRed: 0.19, green: 0.85, blue: 0.40, alpha: 1.0), // Emerald (DB)
    NSColor(calibratedRed: 0.49, green: 0.43, blue: 0.96, alpha: 1.0), // Indigo (PHP)
    NSColor(calibratedRed: 1.00, green: 0.44, blue: 0.18, alpha: 1.0), // Coral-Orange (Apache/XAMPP)
]

for (idx, y) in bladeYs.enumerated() {
    let bladeShadow = CALayer()
    bladeShadow.frame = CGRect(x: bladeX, y: y, width: bladeWidth, height: bladeHeight)
    bladeShadow.shadowColor = NSColor.black.cgColor
    bladeShadow.shadowOpacity = 0.38
    bladeShadow.shadowOffset = CGSize(width: 0, height: -10)
    bladeShadow.shadowRadius = 14

    let blade = CAGradientLayer()
    blade.frame = bladeShadow.bounds
    blade.cornerRadius = 36
    blade.cornerCurve = .continuous
    blade.masksToBounds = true
    blade.colors = [
        NSColor(calibratedRed: 0.83, green: 0.85, blue: 0.89, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1.0).cgColor,
    ]
    blade.startPoint = CGPoint(x: 0.5, y: 0.0)
    blade.endPoint = CGPoint(x: 0.5, y: 1.0)

    // Subtle top edge highlight on blade
    let bladeHighlight = CALayer()
    bladeHighlight.frame = blade.bounds.insetBy(dx: 1, dy: 1)
    bladeHighlight.cornerRadius = 35
    bladeHighlight.cornerCurve = .continuous
    bladeHighlight.borderWidth = 2
    bladeHighlight.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.85).cgColor
    blade.addSublayer(bladeHighlight)

    // Glowing status jewel on the left
    let ledSize: CGFloat = 34
    let ledHalo = CALayer()
    ledHalo.frame = CGRect(x: 34, y: (bladeHeight - 54) / 2, width: 54, height: 54)
    ledHalo.cornerRadius = 27
    ledHalo.backgroundColor = ledColors[idx].withAlphaComponent(0.24).cgColor
    blade.addSublayer(ledHalo)

    let led = CALayer()
    led.frame = CGRect(x: 44, y: (bladeHeight - ledSize) / 2, width: ledSize, height: ledSize)
    led.cornerRadius = ledSize / 2
    led.backgroundColor = ledColors[idx].cgColor
    led.shadowColor = ledColors[idx].cgColor
    led.shadowOpacity = 0.7
    led.shadowRadius = 8
    led.shadowOffset = .zero
    blade.addSublayer(led)

    // Specular dot inside jewel
    let dot = CALayer()
    dot.frame = CGRect(x: 7, y: 19, width: 9, height: 9)
    dot.cornerRadius = 4.5
    dot.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.72).cgColor
    led.addSublayer(dot)

    // Precision machined vent slots on right
    for s in 0..<2 {
        let slot = CALayer()
        let sw: CGFloat = s == 0 ? 156 : 96
        slot.frame = CGRect(
            x: bladeWidth - 48 - sw - CGFloat(s) * 0,
            y: s == 0 ? 68 : 40,
            width: sw,
            height: 14
        )
        slot.cornerRadius = 7
        slot.backgroundColor = NSColor(calibratedRed: 0.25, green: 0.28, blue: 0.34, alpha: 0.28).cgColor
        blade.addSublayer(slot)
    }

    bladeShadow.addSublayer(blade)
    tile.addSublayer(bladeShadow)
}

root.render(in: ctx)
NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encoding failed") }
try pngData.write(to: URL(fileURLWithPath: masterPng))

try? FileManager.default.removeItem(atPath: iconsetDir)
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let masterImage = NSImage(cgImage: rep.cgImage!, size: NSSize(width: size, height: size))
let targets: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in targets {
    let outRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    outRep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: outRep)
    NSGraphicsContext.current?.imageInterpolation = .high
    masterImage.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    if let data = outRep.representation(using: .png, properties: [:]) {
        try data.write(to: URL(fileURLWithPath: (iconsetDir as NSString).appendingPathComponent(name)))
        if name == "icon_512x512.png" {
            let logoPath = (outDir as NSString).appendingPathComponent("logo.png")
            try data.write(to: URL(fileURLWithPath: logoPath))
        }
    }
}
print("Generated iconset at \(iconsetDir)")

