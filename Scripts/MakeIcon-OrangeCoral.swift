import AppKit
import CoreGraphics

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.interpolationQuality = .high
let canvas = CGRect(x: 78, y: 78, width: 868, height: 868)
let outer = CGPath(roundedRect: canvas, cornerWidth: 205, cornerHeight: 205, transform: nil)
context.saveGState()
context.addPath(outer)
context.clip()
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(red: 1.00, green: 0.62, blue: 0.18, alpha: 1),
                                   CGColor(red: 0.96, green: 0.28, blue: 0.24, alpha: 1)] as CFArray,
                          locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 178, y: 870), end: CGPoint(x: 870, y: 150), options: [])
context.restoreGState()

// Video frame
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
context.setLineWidth(47)
context.setLineJoin(.round)
let frame = CGPath(roundedRect: CGRect(x: 248, y: 339, width: 528, height: 358), cornerWidth: 85, cornerHeight: 85, transform: nil)
context.addPath(frame)
context.strokePath()

// Play symbol
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.98))
context.move(to: CGPoint(x: 454, y: 427))
context.addLine(to: CGPoint(x: 454, y: 606))
context.addLine(to: CGPoint(x: 610, y: 516))
context.closePath()
context.fillPath()

// Download badge
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 25,
                  color: CGColor(red: 0.55, green: 0.12, blue: 0.08, alpha: 0.30))
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fillEllipse(in: CGRect(x: 628, y: 190, width: 222, height: 222))
context.setShadow(offset: .zero, blur: 0)
context.setStrokeColor(CGColor(red: 0.76, green: 0.18, blue: 0.12, alpha: 1))
context.setLineWidth(28)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 739, y: 339))
context.addLine(to: CGPoint(x: 739, y: 260))
context.move(to: CGPoint(x: 695, y: 294))
context.addLine(to: CGPoint(x: 739, y: 250))
context.addLine(to: CGPoint(x: 783, y: 294))
context.strokePath()

let image = context.makeImage()!
let bitmap = NSBitmapImageRep(cgImage: image)
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
