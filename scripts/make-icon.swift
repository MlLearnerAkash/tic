#!/usr/bin/env swift
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
ctx.setAllowsAntialiasing(true)

// Background squircle
let bgRect = NSRect(x: 68, y: 68, width: size - 136, height: size - 136)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 218, yRadius: 218)
let bgGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.995, green: 0.984, blue: 0.955, alpha: 1),
    NSColor(calibratedRed: 0.945, green: 0.918, blue: 0.855, alpha: 1)
])!
bgGradient.draw(in: bgPath, angle: -90)

// Soft shadow ring
NSColor(calibratedWhite: 0, alpha: 0.06).setStroke()
bgPath.lineWidth = 4
bgPath.stroke()

// Accent tile
let tileRect = NSRect(x: 232, y: 232, width: size - 464, height: size - 464)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 128, yRadius: 128)
let accentGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.965, green: 0.435, blue: 0.195, alpha: 1),
    NSColor(calibratedRed: 0.885, green: 0.285, blue: 0.105, alpha: 1)
])!
accentGradient.draw(in: tile, angle: -75)

// Checkmark
let check = NSBezierPath()
check.move(to: NSPoint(x: 352, y: 536))
check.line(to: NSPoint(x: 472, y: 416))
check.line(to: NSPoint(x: 690, y: 646))
check.lineWidth = 58
check.lineCapStyle = .round
check.lineJoinStyle = .round
NSColor.white.setStroke()
check.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: "Resources/icon-1024.png"))
print("Wrote Resources/icon-1024.png")
