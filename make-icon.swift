import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// 生成 App 图标，写入 Assets.xcassets/AppIcon.appiconset

let iconsetDir = "Assets.xcassets/AppIcon.appiconset"

try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
try? "{\"info\":{\"author\":\"xcode\",\"version\":1}}"
    .write(toFile: "Assets.xcassets/Contents.json", atomically: true, encoding: .utf8)

let specs: [(name: String, size: Int)] = [
    ("Icon-20@2x.png", 40),
    ("Icon-20@3x.png", 60),
    ("Icon-29@2x.png", 58),
    ("Icon-29@3x.png", 87),
    ("Icon-40@2x.png", 80),
    ("Icon-40@3x.png", 120),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-1024.png", 1024)
]

func drawIcon(pixelSize: Int, to path: String) {
    let s = CGFloat(pixelSize)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil,
                              width: pixelSize,
                              height: pixelSize,
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return
    }

    // 背景渐变
    let colors = [
        CGColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1.0),
        CGColor(red: 0.09, green: 0.20, blue: 0.35, alpha: 1.0)
    ] as CFArray
    if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(g,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: s, y: 0),
                               options: [])
    }

    // 圆角边框
    let inset = s * 0.10
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let r = s * 0.14
    let borderPath = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(borderPath)
    ctx.setStrokeColor(CGColor(red: 0.24, green: 0.75, blue: 0.62, alpha: 0.9))
    ctx.setLineWidth(max(1, s * 0.022))
    ctx.strokePath()

    // 文字
    let fontSize = s * 0.34
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, fontSize, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(red: 0.33, green: 0.92, blue: 0.76, alpha: 1.0)
    ]
    guard let attrStr = CFAttributedStringCreate(nil, "cs" as CFString, attrs as CFDictionary) else { return }
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textPosition = CGPoint(x: s / 2 - bounds.width / 2 - bounds.minX,
                               y: s / 2 - bounds.height / 2 - bounds.minY)
    CTLineDraw(line, ctx)

    guard let image = ctx.makeImage() else { return }
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

for spec in specs {
    drawIcon(pixelSize: spec.size, to: iconsetDir + "/" + spec.name)
}

let contents = """
{
  "images" : [
    { "filename" : "Icon-20@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "Icon-20@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "Icon-29@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "Icon-29@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "Icon-40@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "Icon-40@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "Icon-60@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "Icon-60@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "Icon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

try? contents.write(toFile: iconsetDir + "/Contents.json", atomically: true, encoding: .utf8)
print("icon ok")