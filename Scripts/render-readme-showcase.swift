#!/usr/bin/env swift

import AppKit
import Foundation

private struct ThemeSample {
    let percent: Int
    let title: String
    let range: String
    let accent: NSColor
    let image: NSImage
}

private let fileManager = FileManager.default
private let repositoryRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
private let binaryURL = CommandLine.arguments.dropFirst().first.map(URL.init(fileURLWithPath:))
    ?? repositoryRoot.appendingPathComponent(".build/release/QuotaGrove")
private let previewStyle: String? = ProcessInfo.processInfo.environment["QUOTA_GROVE_PREVIEW_STYLE"] ?? "quotaGrove"
private let outputDirectory = repositoryRoot.appendingPathComponent("docs/screenshots", isDirectory: true)
private let temporaryDirectory = fileManager.temporaryDirectory
    .appendingPathComponent("quota-grove-showcase-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)

private let palette = (
    canvasTop: NSColor(calibratedRed: 0.025, green: 0.071, blue: 0.058, alpha: 1),
    canvasBottom: NSColor(calibratedRed: 0.043, green: 0.105, blue: 0.086, alpha: 1),
    panel: NSColor(calibratedRed: 0.060, green: 0.128, blue: 0.105, alpha: 0.88),
    panelStroke: NSColor(calibratedRed: 0.206, green: 0.342, blue: 0.290, alpha: 0.72),
    text: NSColor(calibratedWhite: 0.95, alpha: 1),
    muted: NSColor(calibratedRed: 0.64, green: 0.73, blue: 0.69, alpha: 1),
    desktopTop: NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.79, alpha: 1),
    desktopBottom: NSColor(calibratedRed: 0.66, green: 0.65, blue: 0.61, alpha: 1)
)

private func runPreview(percent: Int, name: String, expanded: Bool = false, stashed: Bool = false) throws -> NSImage {
    let outputURL = temporaryDirectory.appendingPathComponent("\(name).png")
    let process = Process()
    process.executableURL = binaryURL
    process.arguments = ["-AppleLanguages", "(en)", "--render-preview", String(percent), outputURL.path]
        + (expanded ? ["--expanded"] : [])
        + (stashed ? ["--stashed"] : [])
        + (previewStyle.map { ["--background-style", $0] } ?? [])
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0, let image = NSImage(contentsOf: outputURL) else {
        throw NSError(
            domain: "QuotaGroveShowcase",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "无法生成预览：\(name)"]
        )
    }
    return image
}

private func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byTruncatingTail
    (text as NSString).draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )
}

private func drawCanvas(size: NSSize, body: @escaping (NSRect) -> Void) -> NSImage {
    NSImage(size: size, flipped: true) { bounds in
        NSGradient(starting: palette.canvasTop, ending: palette.canvasBottom)?
            .draw(in: bounds, angle: -90)
        body(bounds)
        return true
    }
}

private func drawImage(_ image: NSImage, in rect: NSRect, shadow: Bool = true) {
    NSGraphicsContext.saveGraphicsState()
    if shadow {
        let cardShadow = NSShadow()
        cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
        cardShadow.shadowBlurRadius = 18
        cardShadow.shadowOffset = NSSize(width: 0, height: 8)
        cardShadow.set()
    }
    image.draw(
        in: rect,
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
}

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [.compressionFactor: 0.92])
    else {
        throw NSError(
            domain: "QuotaGroveShowcase",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "无法编码 PNG：\(url.lastPathComponent)"]
        )
    }
    try png.write(to: url, options: .atomic)
}

private func drawHeader(title: String, subtitle: String, width: CGFloat) {
    drawText(
        title,
        in: NSRect(x: 64, y: 42, width: width - 128, height: 52),
        font: .systemFont(ofSize: 38, weight: .semibold),
        color: palette.text
    )
    drawText(
        subtitle,
        in: NSRect(x: 64, y: 98, width: width - 128, height: 34),
        font: .systemFont(ofSize: 20, weight: .regular),
        color: palette.muted
    )
}

private func renderThemeShowcase(samples: [ThemeSample]) -> NSImage {
    let size = NSSize(width: 1600, height: 520)
    return drawCanvas(size: size) { _ in
        drawHeader(
            title: "The landscape changes with your quota",
            subtitle: "Background, border, and progress state respond to your remaining 7-day quota",
            width: size.width
        )

        let panelWidth: CGFloat = 350
        let gap: CGFloat = 26
        let startX: CGFloat = 61

        for (index, sample) in samples.enumerated() {
            let x = startX + CGFloat(index) * (panelWidth + gap)
            let panelRect = NSRect(x: x, y: 164, width: panelWidth, height: 294)
            roundedRect(panelRect, radius: 24, fill: palette.panel, stroke: palette.panelStroke)

            let dotRect = NSRect(x: x + 24, y: 193, width: 12, height: 12)
            NSBezierPath(ovalIn: dotRect).apply {
                sample.accent.setFill()
                $0.fill()
            }
            drawText(
                sample.title,
                in: NSRect(x: x + 48, y: 182, width: 170, height: 34),
                font: .systemFont(ofSize: 22, weight: .medium),
                color: palette.text
            )
            drawText(
                sample.range,
                in: NSRect(x: x + 206, y: 184, width: 118, height: 30),
                font: .monospacedDigitSystemFont(ofSize: 16, weight: .medium),
                color: palette.muted,
                alignment: .right
            )

            drawImage(sample.image, in: NSRect(x: x + 15, y: 244, width: 320, height: 128))
            drawText(
                "\(sample.percent)% remaining",
                in: NSRect(x: x + 24, y: 400, width: panelWidth - 48, height: 30),
                font: .monospacedDigitSystemFont(ofSize: 16, weight: .regular),
                color: palette.muted,
                alignment: .center
            )
        }
    }
}

private func renderModeShowcase(collapsed: NSImage, expanded: NSImage, stashed: NSImage) -> NSImage {
    let size = NSSize(width: 1600, height: 760)
    return drawCanvas(size: size) { _ in
        drawHeader(
            title: "Three display states",
            subtitle: "Keep the essentials compact, expand for details, or stash the card at the screen edge",
            width: size.width
        )

        let panels = [
            NSRect(x: 50, y: 164, width: 480, height: 520),
            NSRect(x: 560, y: 164, width: 480, height: 520),
            NSRect(x: 1070, y: 164, width: 480, height: 520)
        ]
        let titles = ["Compact", "Expanded", "Edge-stashed"]
        let captions = ["Quota, reset time, and progress", "Plan details and last data update", "Hover to slide the full card back out"]

        for index in panels.indices {
            roundedRect(panels[index], radius: 28, fill: palette.panel, stroke: palette.panelStroke)
            drawText(
                titles[index],
                in: NSRect(x: panels[index].minX + 30, y: 195, width: 180, height: 40),
                font: .systemFont(ofSize: 25, weight: .medium),
                color: palette.text
            )
            drawText(
                captions[index],
                in: NSRect(x: panels[index].minX + 30, y: 625, width: panels[index].width - 60, height: 34),
                font: .systemFont(ofSize: 17, weight: .regular),
                color: palette.muted,
                alignment: .center
            )
        }

        drawImage(collapsed, in: NSRect(x: 90, y: 354, width: 400, height: 160))
        drawImage(expanded, in: NSRect(x: 600, y: 255, width: 400, height: 356))

        let desktopRect = NSRect(x: 1110, y: 254, width: 400, height: 356)
        let desktopPath = NSBezierPath(roundedRect: desktopRect, xRadius: 22, yRadius: 22)
        NSGraphicsContext.saveGraphicsState()
        desktopPath.addClip()
        NSGradient(starting: palette.desktopTop, ending: palette.desktopBottom)?
            .draw(in: desktopRect, angle: -75)
        let edgeShade = NSRect(x: desktopRect.maxX - 48, y: desktopRect.minY, width: 48, height: desktopRect.height)
        NSColor.black.withAlphaComponent(0.12).setFill()
        edgeShade.fill()
        NSGraphicsContext.restoreGraphicsState()
        palette.panelStroke.setStroke()
        desktopPath.lineWidth = 1
        desktopPath.stroke()

        drawImage(
            stashed,
            in: NSRect(x: desktopRect.maxX - 32, y: desktopRect.midY - 80, width: 32, height: 160),
            shadow: true
        )
        drawText(
            "Screen edge",
            in: NSRect(x: desktopRect.maxX - 145, y: desktopRect.minY + 24, width: 110, height: 26),
            font: .systemFont(ofSize: 15, weight: .medium),
            color: NSColor(calibratedWhite: 0.22, alpha: 0.76),
            alignment: .right
        )
    }
}

private extension NSBezierPath {
    func apply(_ body: (NSBezierPath) -> Void) {
        body(self)
    }
}

do {
    guard fileManager.isExecutableFile(atPath: binaryURL.path) else {
        throw NSError(
            domain: "QuotaGroveShowcase",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "请先执行 swift build -c release"]
        )
    }
    try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryDirectory) }

    let samples = try [
        ThemeSample(percent: 85, title: "Healthy", range: "70–100%", accent: NSColor(calibratedRed: 0.47, green: 0.88, blue: 0.67, alpha: 1), image: runPreview(percent: 85, name: "forest")),
        ThemeSample(percent: 55, title: "Reduced", range: "40–69%", accent: NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.29, alpha: 1), image: runPreview(percent: 55, name: "autumn")),
        ThemeSample(percent: 25, title: "Low", range: "10–39%", accent: NSColor(calibratedRed: 0.94, green: 0.29, blue: 0.28, alpha: 1), image: runPreview(percent: 25, name: "apocalypse")),
        ThemeSample(percent: 5, title: "Nearly depleted", range: "0–9%", accent: NSColor(calibratedWhite: 0.94, alpha: 1), image: runPreview(percent: 5, name: "wasteland"))
    ]
    let collapsed = try runPreview(percent: 54, name: "collapsed")
    let expanded = try runPreview(percent: 54, name: "expanded", expanded: true)
    let stashed = try runPreview(percent: 54, name: "stashed", stashed: true)

    let themeFilename: String
    let modeFilename: String
    switch previewStyle {
    case "astralTerrarium":
        themeFilename = "quota-grove-astral-terrarium-themes.png"
        modeFilename = "quota-grove-astral-terrarium-modes.png"
    case "cloudseaBeacon":
        themeFilename = "quota-grove-cloudsea-beacon-themes.png"
        modeFilename = "quota-grove-cloudsea-beacon-modes.png"
    case "moonlitConservatory":
        themeFilename = "quota-grove-moonlit-conservatory-themes.png"
        modeFilename = "quota-grove-moonlit-conservatory-modes.png"
    case "abyssalReverie":
        themeFilename = "quota-grove-abyssal-reverie-themes.png"
        modeFilename = "quota-grove-abyssal-reverie-modes.png"
    case "chronoforge":
        themeFilename = "quota-grove-chronoforge-themes.png"
        modeFilename = "quota-grove-chronoforge-modes.png"
    default:
        themeFilename = "quota-grove-themes-en-v101.png"
        modeFilename = "quota-grove-modes-en-v101.png"
    }
    let themeURL = outputDirectory.appendingPathComponent(themeFilename)
    let modeURL = outputDirectory.appendingPathComponent(modeFilename)
    try writePNG(renderThemeShowcase(samples: samples), to: themeURL)
    try writePNG(renderModeShowcase(collapsed: collapsed, expanded: expanded, stashed: stashed), to: modeURL)

    print(themeURL.path)
    print(modeURL.path)
} catch {
    FileHandle.standardError.write(Data("生成 README 展示图失败：\(error.localizedDescription)\n".utf8))
    exit(1)
}
