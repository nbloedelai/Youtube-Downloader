import AppKit

guard CommandLine.arguments.count == 3,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: MakeDMGBackground input.png output.png")
}

let size = NSSize(width: 660, height: 420)
let image = NSImage(size: size)
image.lockFocus()
source.draw(in: NSRect(origin: .zero, size: size))

let pill = NSBezierPath(roundedRect: NSRect(x: 174, y: 342, width: 312, height: 52), xRadius: 26, yRadius: 26)
NSColor.white.withAlphaComponent(0.72).setFill()
pill.fill()
NSColor(calibratedRed: 0.96, green: 0.32, blue: 0.25, alpha: 0.18).setStroke()
pill.lineWidth = 1
pill.stroke()

let title = NSAttributedString(
    string: "Drag to Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 19, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.27, alpha: 1)
    ]
)
let titleSize = title.size()
title.draw(at: NSPoint(x: (size.width - titleSize.width) / 2, y: 364 - titleSize.height / 2))

let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 270, y: 198))
arrow.curve(to: NSPoint(x: 390, y: 198), controlPoint1: NSPoint(x: 310, y: 218), controlPoint2: NSPoint(x: 350, y: 178))
NSColor(calibratedRed: 0.96, green: 0.32, blue: 0.25, alpha: 0.92).setStroke()
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.lineWidth = 5
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.move(to: NSPoint(x: 373, y: 216))
arrowHead.line(to: NSPoint(x: 394, y: 198))
arrowHead.line(to: NSPoint(x: 373, y: 180))
arrowHead.stroke()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode PNG")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
