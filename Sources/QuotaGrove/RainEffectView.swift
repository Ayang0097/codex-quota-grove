import AppKit

final class RainEffectView: NSView {
    private var particles = RainParticleSystem()
    private var animationTimer: Timer?
    private var previousTick: TimeInterval = 0
    private var previewIsActive = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        animationTimer?.invalidate()
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setAnimating(_ active: Bool) {
        guard active else {
            animationTimer?.invalidate()
            animationTimer = nil
            particles.removeAll()
            isHidden = true
            needsDisplay = true
            return
        }

        isHidden = false
        if particles.isEmpty { particles.start(in: bounds.size) }
        guard animationTimer == nil else { return }

        previousTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            self.particles.advance(by: now - self.previousTick, in: self.bounds.size)
            self.previousTick = now
            self.needsDisplay = true
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func setPreviewActive(_ active: Bool) {
        previewIsActive = active
        isHidden = !active
        if active {
            particles.start(in: bounds.size)
        } else {
            particles.removeAll()
        }
        needsDisplay = true
    }

    func advancePreview(by deltaTime: TimeInterval) {
        guard previewIsActive else { return }
        particles.advance(by: deltaTime, in: bounds.size)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawForPreview()
    }

    func drawForPreview() {
        guard !particles.isEmpty else { return }

        let clip = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 18,
            yRadius: 18
        )
        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        drawRain()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawRain() {
        NSColor(calibratedRed: 0.012, green: 0.052, blue: 0.064, alpha: 0.115).setFill()
        bounds.fill()

        drawRainVeil()

        for drop in particles.drops {
            draw(drop)
        }

        for splash in particles.splashes {
            draw(splash)
        }
    }

    private func drawRainVeil() {
        let veilColor = NSColor(calibratedRed: 0.68, green: 0.84, blue: 0.89, alpha: 1)
        let bands: [(x: CGFloat, width: CGFloat, opacity: CGFloat)] = [
            (bounds.width * 0.63, 7.5, 0.014),
            (bounds.width * 0.77, 11, 0.011),
            (bounds.width * 0.91, 6, 0.016)
        ]

        for band in bands {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: band.x + 24, y: bounds.maxY + 8))
            path.line(to: NSPoint(x: band.x - 15, y: bounds.minY - 8))
            path.lineWidth = band.width
            path.lineCapStyle = .round
            veilColor.withAlphaComponent(band.opacity).setStroke()
            path.stroke()
        }
    }

    private func draw(_ drop: RainDrop) {
        let speed = max(1, hypot(drop.windSpeed, drop.fallSpeed))
        let direction = CGVector(
            dx: -drop.windSpeed / speed * drop.length,
            dy: drop.fallSpeed / speed * drop.length
        )
        let normal = CGVector(dx: -direction.dy / drop.length, dy: direction.dx / drop.length)
        let fractions: [CGFloat] = [0, 0.16, 0.4, 0.7, 1]
        let widthScales: [CGFloat] = [1.08, 0.82, 0.5, 0.22]
        let opacityScales: [CGFloat] = [1, 0.78, 0.47, 0.18]
        let shimmer = drop.shimmer

        let layerColors: [NSColor] = [
            NSColor(calibratedRed: 0.68, green: 0.82, blue: 0.86, alpha: 1),
            NSColor(calibratedRed: 0.78, green: 0.91, blue: 0.94, alpha: 1),
            NSColor(calibratedRed: 0.9, green: 0.98, blue: 1, alpha: 1)
        ]
        let layer = drop.depth < 0.36 ? 0 : (drop.depth < 0.76 ? 1 : 2)
        let color = layerColors[layer]

        func point(at fraction: CGFloat, offset: CGFloat = 0) -> NSPoint {
            let bow = sin(.pi * fraction) * drop.curvature + offset
            return NSPoint(
                x: drop.position.x + direction.dx * fraction + normal.dx * bow,
                y: drop.position.y + direction.dy * fraction + normal.dy * bow
            )
        }

        if layer == 2 {
            let halo = NSBezierPath()
            halo.move(to: point(at: 0))
            halo.line(to: point(at: 1))
            halo.lineWidth = drop.lineWidth * 2.75
            halo.lineCapStyle = .round
            color.withAlphaComponent(0.075 * drop.opacity * shimmer).setStroke()
            halo.stroke()
        }

        for segmentIndex in 0..<4 {
            let path = NSBezierPath()
            path.move(to: point(at: fractions[segmentIndex]))
            path.line(to: point(at: fractions[segmentIndex + 1]))
            path.lineWidth = max(0.07, drop.lineWidth * widthScales[segmentIndex])
            path.lineCapStyle = .round
            color
                .withAlphaComponent(drop.opacity * shimmer * opacityScales[segmentIndex])
                .setStroke()
            path.stroke()
        }

        guard layer >= 1 else { return }

        let headSize = max(0.42, drop.lineWidth * (layer == 2 ? 1.65 : 1.25))
        let headRect = NSRect(
            x: drop.position.x - headSize / 2,
            y: drop.position.y - headSize / 2,
            width: headSize,
            height: headSize
        )
        color.withAlphaComponent(drop.opacity * shimmer * (layer == 2 ? 0.9 : 0.58)).setFill()
        NSBezierPath(ovalIn: headRect).fill()

        if layer == 2 {
            let refraction = NSBezierPath()
            refraction.move(to: point(at: 0.04, offset: 0.48))
            refraction.line(to: point(at: 0.46, offset: 0.32))
            refraction.lineWidth = max(0.08, drop.lineWidth * 0.32)
            refraction.lineCapStyle = .round
            NSColor.white.withAlphaComponent(drop.opacity * shimmer * 0.38).setStroke()
            refraction.stroke()
        }
    }

    private func draw(_ splash: RainSplash) {
        let progress = splash.progress
        let opacity = splash.opacity
        let width = splash.size * (0.46 + progress * 1.02)
        let rippleRect = NSRect(
            x: splash.position.x - width / 2,
            y: splash.position.y - 0.75,
            width: width,
            height: max(0.9, width * 0.23)
        )
        let ripple = NSBezierPath(ovalIn: rippleRect)
        ripple.lineWidth = 0.58
        NSColor(calibratedRed: 0.76, green: 0.92, blue: 0.96, alpha: 0.36 * opacity).setStroke()
        ripple.stroke()

        if progress < 0.56 {
            let lift = (1 - progress / 0.56) * splash.size * 0.56
            for direction: CGFloat in [-1, 1] {
                let bead = NSBezierPath()
                bead.move(to: NSPoint(x: splash.position.x + direction * 0.5, y: splash.position.y + 0.35))
                bead.line(to: NSPoint(x: splash.position.x + direction * splash.size * 0.26, y: splash.position.y + lift))
                bead.lineWidth = 0.62
                bead.lineCapStyle = .round
                NSColor(calibratedRed: 0.84, green: 0.96, blue: 1, alpha: 0.42 * opacity).setStroke()
                bead.stroke()
            }
        }
    }
}
