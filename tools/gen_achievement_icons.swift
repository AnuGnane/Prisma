#!/usr/bin/env swift

//
//  gen_achievement_icons.swift
//  Prisma — dev tooling
//
//  Renders 7 App Store Connect achievement icons (512×512 PNG) by combining a
//  game-themed gradient backdrop with a centered SF Symbol. Output goes to
//  `tools/achievement_images/<id>.png`. Drop these into ASC under
//  Game Center → Achievements when configuring the entries listed in
//  GAME_CENTER_STATUS.md.
//
//  Usage (from the Xcode project root, e.g. `Prisma/Prisma/`):
//
//      swift tools/gen_achievement_icons.swift
//
//  Requires macOS 12+ (uses NSImage.SymbolConfiguration palette colours).
//
//  Re-run this any time the gradients or SF Symbol choices change. The output
//  is fully deterministic, so you can commit the PNGs alongside the script.
//

import AppKit
import Foundation

// MARK: - Spec

struct AchievementIcon {
    let id: String
    let symbol: String
    let gradient: (start: NSColor, end: NSColor)
}

private func sRGB(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
    NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
}

// Gradient pairs sourced from AppTheme.swift to keep visual continuity
// with the in-app per-game accents.
private let signalsGradient = (start: sRGB(0.12, 0.50, 0.30), end: sRGB(0.20, 0.72, 0.50))
private let cargoGradient   = (start: sRGB(0.85, 0.42, 0.12), end: sRGB(1.00, 0.62, 0.30))
private let shiftGradient   = (start: sRGB(0.50, 0.16, 0.72), end: sRGB(0.72, 0.34, 0.92))
private let circuitGradient = (start: sRGB(0.00, 0.55, 0.75), end: sRGB(0.00, 0.85, 1.00))
private let archiveGradient = (start: sRGB(0.16, 0.38, 0.72), end: sRGB(0.30, 0.58, 0.92))

let achievements: [AchievementIcon] = [
    AchievementIcon(id: "prisma.first_signal",    symbol: "antenna.radiowaves.left.and.right", gradient: signalsGradient),
    AchievementIcon(id: "prisma.first_archive",   symbol: "clock.arrow.circlepath",            gradient: archiveGradient),
    AchievementIcon(id: "prisma.first_cargo",     symbol: "shippingbox.fill",                  gradient: cargoGradient),
    AchievementIcon(id: "prisma.first_shift",     symbol: "slider.horizontal.3",               gradient: shiftGradient),
    AchievementIcon(id: "prisma.first_circuit",   symbol: "bolt.horizontal.fill",              gradient: circuitGradient),
    AchievementIcon(id: "prisma.perfect_signal",  symbol: "bolt.fill",                         gradient: signalsGradient),
    AchievementIcon(id: "prisma.perfect_archive", symbol: "scope",                             gradient: archiveGradient),
    AchievementIcon(id: "prisma.perfect_cargo",   symbol: "square.grid.3x3.fill",              gradient: cargoGradient),
    AchievementIcon(id: "prisma.perfect_shift",   symbol: "arrow.uturn.backward.circle.fill",  gradient: shiftGradient),
    AchievementIcon(id: "prisma.perfect_circuit", symbol: "star.circle.fill",                  gradient: circuitGradient),
]

// MARK: - Renderer

let canvasSize = NSSize(width: 512, height: 512)
let symbolPointSize: CGFloat = 256

let outputDir = URL(fileURLWithPath: "tools/achievement_images")

do {
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write(Data("Failed to create output dir: \(error)\n".utf8))
    exit(1)
}

var failures: [String] = []

for spec in achievements {
    let image = NSImage(size: canvasSize)
    image.lockFocus()

    // 1. Gradient background — diagonal sweep from the deeper colour at
    // bottom-left to the lighter shade at top-right (NSGradient angles
    // sweep counter-clockwise from 0° = right).
    if let bg = NSGradient(starting: spec.gradient.start, ending: spec.gradient.end) {
        bg.draw(in: NSRect(origin: .zero, size: canvasSize), angle: 45)
    }

    // 2. Centered white SF Symbol. `paletteColors` reliably tints both
    // monochrome and palette-style symbols to a single colour.
    let sizeConfig = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
    let whiteConfig = NSImage.SymbolConfiguration(paletteColors: [.white])
    let combined = sizeConfig.applying(whiteConfig)

    if let symbolBase = NSImage(systemSymbolName: spec.symbol, accessibilityDescription: nil),
       let symbol = symbolBase.withSymbolConfiguration(combined) {
        let drawSize = symbol.size
        let rect = NSRect(
            x: (canvasSize.width  - drawSize.width)  / 2,
            y: (canvasSize.height - drawSize.height) / 2,
            width:  drawSize.width,
            height: drawSize.height
        )
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    } else {
        failures.append("\(spec.id): missing SF Symbol '\(spec.symbol)'")
    }

    image.unlockFocus()

    // 3. Encode as PNG.
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        failures.append("\(spec.id): failed to encode PNG")
        continue
    }

    let url = outputDir.appendingPathComponent("\(spec.id).png")
    do {
        try png.write(to: url)
        print("✓ \(url.path) (\(png.count) bytes)")
    } catch {
        failures.append("\(spec.id): write failed — \(error)")
    }
}

print("")
if failures.isEmpty {
    print("Done. \(achievements.count) achievement images written to \(outputDir.path)/")
    print("Next: upload each PNG in App Store Connect under Game Center → Achievements.")
} else {
    print("Completed with \(failures.count) failure(s):")
    for f in failures { print("  · \(f)") }
    exit(2)
}
