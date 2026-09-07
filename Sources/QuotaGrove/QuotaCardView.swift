import AppKit

enum StashedEdge: String {
    case left
    case right
}

protocol QuotaCardViewDelegate: AnyObject {
    func cardViewDidSingleClick(_ view: QuotaCardView)
    func cardViewDidDoubleClick(_ view: QuotaCardView)
    func cardView(_ view: QuotaCardView, dragTo origin: NSPoint)
    func cardViewDidEndDragging(_ view: QuotaCardView)
    func cardViewPointerEntered(_ view: QuotaCardView)
    func cardViewPointerExited(_ view: QuotaCardView)
    func cardView(_ view: QuotaCardView, showContextMenu event: NSEvent)
}

final class QuotaCardView: NSView {
    private static let cardBorderWidth: CGFloat = 0.5

    static let ambientLeafInterval: TimeInterval = 3

    weak var delegate: QuotaCardViewDelegate?

    var snapshot: QuotaSnapshot? {
        didSet {
            if let previous = oldValue, let current = snapshot {
                let percentageDrop = previous.roundedRemaining - current.roundedRemaining
                if percentageDrop > 0 { emitThemeParticles(forPercentageDrop: percentageDrop) }
            }
            updateAccessibility()
            updateRainAnimationState()
            updateSnowAnimationState()
            needsDisplay = true
        }
    }
    var isExpanded = false {
        didSet {
            guard oldValue != isExpanded else { return }
            updateAccessibility()
            needsDisplay = true
        }
    }
    var isStashed = false {
        didSet {
            guard oldValue != isStashed else { return }
            updateTrackingAreas()
            updateAccessibility()
            updateRainAnimationState()
            updateSnowAnimationState()
            needsDisplay = true
        }
    }
    var stashedEdge: StashedEdge = .right {
        didSet {
            guard oldValue != stashedEdge else { return }
            needsDisplay = true
        }
    }

    private var startMouseLocation = NSPoint.zero
    private var startWindowOrigin = NSPoint.zero
    private var didDrag = false
    private var pendingSingleClick: DispatchWorkItem?
    private var hoverTrackingArea: NSTrackingArea?
    private var leafParticles = LeafParticleSystem()
    private var astralParticles = AstralParticleSystem()
    private var beaconParticles = BeaconParticleSystem()
    private var moonButterflies = MoonButterflySystem()
    private var abyssalJellyfish = AbyssalJellyfishSystem()
    private var chronoforgeOrbits = ChronoforgeOrbitSystem()
    private let rainEffectView = RainEffectView(frame: .zero)
    private let snowEffectView = SnowEffectView(frame: .zero)
    private var weatherRainRequested = false
    private var snowEffectRequested = false
    private var cardPresentationActive = false
    private var leafAnimationTimer: Timer?
    private var ambientLeafTimer: Timer?
    private var previousLeafTick: TimeInterval = 0
    private lazy var codexIcon: NSImage? = {
        if let bundledURL = Bundle.main.url(forResource: "CodexIcon", withExtension: "png"),
           let image = NSImage(contentsOf: bundledURL) {
            return image
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets/CodexIcon.png")
        return NSImage(contentsOf: developmentURL)
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        rainEffectView.frame = bounds
        rainEffectView.autoresizingMask = [.width, .height]
        addSubview(rainEffectView)
        snowEffectView.frame = bounds
        snowEffectView.autoresizingMask = [.width, .height]
        addSubview(snowEffectView)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        updateAccessibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        leafAnimationTimer?.invalidate()
        ambientLeafTimer?.invalidate()
    }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        delegate?.cardViewPointerEntered(self)
    }

    override func mouseExited(with event: NSEvent) {
        delegate?.cardViewPointerExited(self)
    }

    override func mouseDown(with event: NSEvent) {
        pendingSingleClick?.cancel()
        startMouseLocation = NSEvent.mouseLocation
        startWindowOrigin = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let deltaX = current.x - startMouseLocation.x
        let deltaY = current.y - startMouseLocation.y
        if abs(deltaX) > 2 || abs(deltaY) > 2 { didDrag = true }
        guard didDrag else { return }
        delegate?.cardView(
            self,
            dragTo: NSPoint(x: startWindowOrigin.x + deltaX, y: startWindowOrigin.y + deltaY)
        )
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            delegate?.cardViewDidEndDragging(self)
            return
        }

        if event.clickCount >= 2 {
            pendingSingleClick?.cancel()
            playManualLeafBurst()
            delegate?.cardViewDidDoubleClick(self)
            return
        }

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.delegate?.cardViewDidSingleClick(self)
        }
        pendingSingleClick = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: task)
    }

    override func rightMouseDown(with event: NSEvent) {
        pendingSingleClick?.cancel()
        delegate?.cardView(self, showContextMenu: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSGraphicsContext.current?.imageInterpolation = .high
        isStashed ? drawStashedBar() : drawCard()
    }

    func refreshClock() {
        updateAccessibility()
        needsDisplay = true
    }

    func advanceLeafAnimationForPreview(by deltaTime: TimeInterval) {
        leafParticles.advance(by: deltaTime)
        astralParticles.advance(by: deltaTime)
        beaconParticles.advance(by: deltaTime)
        moonButterflies.advance(by: deltaTime)
        abyssalJellyfish.advance(by: deltaTime)
        chronoforgeOrbits.advance(by: deltaTime)
        needsDisplay = true
    }

    func emitManualLeafBurstForPreview() {
        if ThemeBackgroundStore.shared.usesAstralEffects {
            astralParticles.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesBeaconEffects {
            beaconParticles.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesMoonlitEffects {
            moonButterflies.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesAbyssalEffects {
            abyssalJellyfish.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesChronoforgeEffects {
            chronoforgeOrbits.emitManualBurst(for: currentTheme, in: bounds.size)
        } else {
            leafParticles.emitManualBurst(in: bounds.size)
        }
        needsDisplay = true
    }

    func backgroundStyleDidChange() {
        leafParticles.removeAll()
        astralParticles.removeAll()
        beaconParticles.removeAll()
        moonButterflies.removeAll()
        abyssalJellyfish.removeAll()
        chronoforgeOrbits.removeAll()
        leafAnimationTimer?.invalidate()
        leafAnimationTimer = nil
        needsDisplay = true
        displayIfNeeded()
    }

    func setRainPreviewActive(_ active: Bool) {
        rainEffectView.setPreviewActive(active)
    }

    func advanceRainAnimationForPreview(by deltaTime: TimeInterval) {
        rainEffectView.advancePreview(by: deltaTime)
    }

    func setSnowPreviewActive(_ active: Bool) {
        snowEffectView.setPreviewActive(active)
    }

    func advanceSnowAnimationForPreview(by deltaTime: TimeInterval) {
        snowEffectView.advancePreview(by: deltaTime)
    }

    func displayBaseForPreview(in context: NSGraphicsContext) {
        let rainWasVisible = !rainEffectView.isHidden
        let snowWasVisible = !snowEffectView.isHidden
        rainEffectView.isHidden = true
        snowEffectView.isHidden = true
        displayIgnoringOpacity(bounds, in: context)
        rainEffectView.isHidden = !rainWasVisible
        snowEffectView.isHidden = !snowWasVisible
    }

    func drawVisibleEffectsForPreview() {
        if !rainEffectView.isHidden { rainEffectView.drawForPreview() }
        if !snowEffectView.isHidden { snowEffectView.drawForPreview() }
    }

    func setWeatherRainActive(_ active: Bool) {
        weatherRainRequested = active
        if active {
            snowEffectRequested = false
            snowEffectView.setAnimating(false)
        }
        updateRainAnimationState()
    }

    func setSnowEffectActive(_ active: Bool) {
        snowEffectRequested = active
        if active {
            weatherRainRequested = false
            rainEffectView.setAnimating(false)
        }
        updateSnowAnimationState()
    }

    func setWeatherEffect(_ effect: WeatherEffect) {
        weatherRainRequested = effect == .rain
        snowEffectRequested = effect == .snow
        updateRainAnimationState()
        updateSnowAnimationState()
    }

    func setCardPresentationActive(_ active: Bool) {
        cardPresentationActive = active
        updateRainAnimationState()
        updateSnowAnimationState()
    }

    func setAmbientLeafAnimationActive(_ active: Bool) {
        if !active {
            ambientLeafTimer?.invalidate()
            ambientLeafTimer = nil
            return
        }
        guard ambientLeafTimer == nil else { return }

        let timer = Timer(timeInterval: Self.ambientLeafInterval, repeats: true) { [weak self] _ in
            self?.playAmbientLeafAnimationIfPossible()
        }
        ambientLeafTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func playAmbientLeafAnimationIfPossible() {
        guard snapshot != nil else { return }
        guard !weatherRainRequested, !snowEffectRequested else { return }
        guard window?.isVisible == true,
              !isStashed,
              leafParticles.isEmpty,
              astralParticles.isEmpty,
              beaconParticles.isEmpty,
              moonButterflies.isEmpty,
              abyssalJellyfish.isEmpty,
              chronoforgeOrbits.isEmpty
        else { return }
        if ThemeBackgroundStore.shared.usesAstralEffects {
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            astralParticles.emitAmbient(for: currentTheme, in: bounds.size)
            startLeafAnimationIfNeeded()
        } else if ThemeBackgroundStore.shared.usesBeaconEffects {
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            beaconParticles.emitAmbient(for: currentTheme, in: bounds.size)
            startLeafAnimationIfNeeded()
        } else if ThemeBackgroundStore.shared.usesMoonlitEffects {
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            moonButterflies.emitAmbient(for: currentTheme, in: bounds.size)
            startLeafAnimationIfNeeded()
        } else if ThemeBackgroundStore.shared.usesAbyssalEffects {
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            abyssalJellyfish.emitAmbient(for: currentTheme, in: bounds.size)
            startLeafAnimationIfNeeded()
        } else if ThemeBackgroundStore.shared.usesChronoforgeEffects {
            guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            chronoforgeOrbits.emitAmbient(for: currentTheme, in: bounds.size)
            startLeafAnimationIfNeeded()
        } else {
            emitThemeParticles(forPercentageDrop: 1)
        }
    }

    private func drawStashedBar() {
        // Extend the rounded card beyond the screen edge, leaving a single
        // curved slice visible instead of an isolated progress capsule.
        let hiddenExtension: CGFloat = 18
        let shellRect: NSRect
        switch stashedEdge {
        case .right:
            shellRect = NSRect(
                x: 0.5,
                y: 0.5,
                width: bounds.width + hiddenExtension,
                height: bounds.height - 1
            )
        case .left:
            shellRect = NSRect(
                x: -hiddenExtension + 0.5,
                y: 0.5,
                width: bounds.width + hiddenExtension,
                height: bounds.height - 1
            )
        }

        let shell = NSBezierPath(roundedRect: shellRect, xRadius: 18, yRadius: 18)
        NSGraphicsContext.saveGraphicsState()
        shell.addClip()
        drawEnvironment(in: shellRect)
        NSColor(calibratedWhite: 0, alpha: 0.48).setFill()
        shell.fill()
        NSGraphicsContext.restoreGraphicsState()

        currentBorderColor.setStroke()
        shell.lineWidth = Self.cardBorderWidth
        shell.stroke()

        let trackRect = NSRect(
            x: (bounds.width - 5) / 2,
            y: 15,
            width: 5,
            height: bounds.height - 30
        )
        let track = NSBezierPath(roundedRect: trackRect, xRadius: 2.5, yRadius: 2.5)
        NSColor(calibratedWhite: 0.02, alpha: 0.74).setFill()
        track.fill()

        let remaining = CGFloat(snapshot?.remainingPercent ?? 0) / 100
        let fillHeight = max(snapshot == nil ? 0 : 4, trackRect.height * remaining)
        guard fillHeight > 0 else { return }
        let fillRect = NSRect(
            x: trackRect.minX,
            y: trackRect.minY,
            width: trackRect.width,
            height: fillHeight
        )
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        NSGraphicsContext.saveGraphicsState()
        fill.addClip()
        let accent = snapshot.map { QuotaTheme.select(for: $0.remainingPercent).progressAccent } ?? .white
        NSGradient(
            starting: accent.blended(withFraction: 0.40, of: .black) ?? accent,
            ending: accent.blended(withFraction: 0.16, of: .black) ?? accent
        )?.draw(in: fillRect, angle: 90)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.12).setStroke()
        track.lineWidth = 0.7
        track.stroke()
    }

    private func drawCard() {
        let cardRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let clip = NSBezierPath(roundedRect: cardRect, xRadius: 18, yRadius: 18)

        NSGraphicsContext.saveGraphicsState()
        clip.addClip()
        drawEnvironment(in: bounds)
        drawReadabilityOverlay(in: bounds)
        drawFallingLeaves()
        drawAstralMotes()
        drawBeaconBirds()
        drawMoonButterflies()
        drawAbyssalJellyfish()
        drawChronoforgeOrbits()
        NSGraphicsContext.restoreGraphicsState()

        currentBorderColor.setStroke()
        clip.lineWidth = Self.cardBorderWidth
        clip.stroke()

        drawSummary()
        if isExpanded { drawDetails() }
    }

    private func emitThemeParticles(forPercentageDrop drop: Int) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        if ThemeBackgroundStore.shared.usesAstralEffects {
            astralParticles.emit(forPercentageDrop: drop, theme: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesBeaconEffects {
            beaconParticles.emit(forPercentageDrop: drop, theme: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesMoonlitEffects {
            moonButterflies.emit(forPercentageDrop: drop, theme: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesAbyssalEffects {
            abyssalJellyfish.emit(forPercentageDrop: drop, theme: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesChronoforgeEffects {
            chronoforgeOrbits.emit(forPercentageDrop: drop, theme: currentTheme, in: bounds.size)
        } else {
            leafParticles.emit(forPercentageDrop: drop, in: bounds.size)
        }
        startLeafAnimationIfNeeded()
    }

    private func playManualLeafBurst() {
        guard !isStashed, snapshot != nil else { return }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        if ThemeBackgroundStore.shared.usesAstralEffects {
            astralParticles.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesBeaconEffects {
            beaconParticles.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesMoonlitEffects {
            moonButterflies.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesAbyssalEffects {
            abyssalJellyfish.emitManualBurst(for: currentTheme, in: bounds.size)
        } else if ThemeBackgroundStore.shared.usesChronoforgeEffects {
            chronoforgeOrbits.emitManualBurst(for: currentTheme, in: bounds.size)
        } else {
            leafParticles.emitManualBurst(in: bounds.size)
        }
        startLeafAnimationIfNeeded()
    }

    private func startLeafAnimationIfNeeded() {
        guard leafAnimationTimer == nil else { return }

        previousLeafTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            self.leafParticles.advance(by: now - self.previousLeafTick)
            self.astralParticles.advance(by: now - self.previousLeafTick)
            self.beaconParticles.advance(by: now - self.previousLeafTick)
            self.moonButterflies.advance(by: now - self.previousLeafTick)
            self.abyssalJellyfish.advance(by: now - self.previousLeafTick)
            self.chronoforgeOrbits.advance(by: now - self.previousLeafTick)
            self.previousLeafTick = now
            self.needsDisplay = true
            if self.leafParticles.isEmpty,
               self.astralParticles.isEmpty,
               self.beaconParticles.isEmpty,
               self.moonButterflies.isEmpty,
               self.abyssalJellyfish.isEmpty,
               self.chronoforgeOrbits.isEmpty {
                self.leafAnimationTimer?.invalidate()
                self.leafAnimationTimer = nil
            }
        }
        leafAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func drawFallingLeaves() {
        guard !leafParticles.isEmpty else { return }
        let palette = leafPalette(for: currentTheme)
        let visibleLeaves = leafParticles.leaves
            .filter(\.isVisible)
            .sorted { $0.depth < $1.depth }

        for leaf in visibleLeaves {
            let departure = leaf.departureProgress(in: bounds.height)
            if let sprite = LeafSpriteStore.shared.image(
                for: currentTheme,
                variant: leaf.colorVariant,
                softened: leaf.focus != .crisp || departure > 0.68
            ) {
                drawLeafSprite(leaf, image: sprite)
                continue
            }

            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: leaf.renderedX, yBy: leaf.position.y)
            transform.rotate(byDegrees: leaf.rotation)
            let flutterScale = 0.56 + abs(cos(leaf.swayPhase * 0.72)) * 0.44
            let depthScale = (0.62 + leaf.depth * 0.68) * (1 - departure * 0.46)
            transform.scaleX(by: flutterScale * depthScale, yBy: depthScale)
            transform.concat()

            let width = leaf.size
            let halfHeightFactors: [CGFloat] = [0.3, 0.23, 0.36]
            let halfHeight = leaf.size * halfHeightFactors[leaf.colorVariant % halfHeightFactors.count]
            let baseX = -width * 0.4
            let tipX = width * 0.58
            let departureOpacity = CGFloat(pow(Double(1 - departure), 1.18))
            let leafOpacity = leaf.opacity * (0.48 + leaf.depth * 0.52) * departureOpacity
            let shape = NSBezierPath()
            shape.move(to: NSPoint(x: baseX, y: 0))
            shape.curve(
                to: NSPoint(x: tipX, y: 0),
                controlPoint1: NSPoint(x: -width * 0.16, y: halfHeight * 1.06),
                controlPoint2: NSPoint(x: width * 0.34, y: halfHeight * 0.94)
            )
            shape.curve(
                to: NSPoint(x: baseX, y: 0),
                controlPoint1: NSPoint(x: width * 0.3, y: -halfHeight * 0.9),
                controlPoint2: NSPoint(x: -width * 0.2, y: -halfHeight * 1.02)
            )
            shape.close()

            let paletteColor = palette[leaf.colorVariant % palette.count]
            let distanceShade = (1 - leaf.depth) * 0.2
            let baseColor = paletteColor.blended(withFraction: distanceShade, of: .black) ?? paletteColor
            let shadowColor = baseColor.blended(withFraction: 0.28, of: .black) ?? baseColor
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent((0.12 + leaf.depth * 0.2) * leafOpacity)
            shadow.shadowBlurRadius = 0.7 + leaf.depth * 1.1
            shadow.shadowOffset = NSSize(width: 0.4 + leaf.depth * 0.4, height: -0.5 - leaf.depth * 0.5)
            shadow.set()
            shadowColor.withAlphaComponent(0.96 * leafOpacity).setFill()
            shape.fill()

            NSShadow().set()
            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            let dark = (baseColor.blended(withFraction: 0.3, of: .black) ?? baseColor)
                .withAlphaComponent(0.96 * leafOpacity)
            let light = (baseColor.blended(withFraction: 0.2, of: .white) ?? baseColor)
                .withAlphaComponent(0.98 * leafOpacity)
            NSGradient(colors: [dark, baseColor.withAlphaComponent(0.98 * leafOpacity), light])?
                .draw(
                    in: NSRect(x: baseX, y: -halfHeight * 1.1, width: tipX - baseX, height: halfHeight * 2.2),
                    angle: 78
                )
            NSGraphicsContext.restoreGraphicsState()

            (baseColor.blended(withFraction: 0.5, of: .black) ?? baseColor)
                .withAlphaComponent(0.72 * leafOpacity)
                .setStroke()
            shape.lineWidth = 0.72
            shape.stroke()

            let veinColor = (baseColor.blended(withFraction: 0.55, of: .black) ?? baseColor)
                .withAlphaComponent((0.56 + leaf.depth * 0.24) * leafOpacity)
            veinColor.setStroke()

            let petiole = NSBezierPath()
            petiole.move(to: NSPoint(x: baseX - width * 0.18, y: -halfHeight * 0.04))
            petiole.curve(
                to: NSPoint(x: baseX + width * 0.05, y: 0),
                controlPoint1: NSPoint(x: baseX - width * 0.1, y: halfHeight * 0.03),
                controlPoint2: NSPoint(x: baseX - width * 0.03, y: -halfHeight * 0.03)
            )
            petiole.lineWidth = 0.85
            petiole.lineCapStyle = .round
            petiole.stroke()

            let vein = NSBezierPath()
            vein.move(to: NSPoint(x: baseX - width * 0.02, y: 0))
            vein.curve(
                to: NSPoint(x: tipX - width * 0.08, y: 0),
                controlPoint1: NSPoint(x: -width * 0.05, y: halfHeight * 0.08),
                controlPoint2: NSPoint(x: width * 0.3, y: -halfHeight * 0.05)
            )
            vein.lineWidth = 0.78
            vein.lineCapStyle = .round
            vein.stroke()

            if leaf.depth > 0.3 {
                let branchCount = leaf.depth > 0.68 ? 4 : 3
                for branchIndex in 1...branchCount {
                    let progress = CGFloat(branchIndex) / CGFloat(branchCount + 1)
                    let x = baseX + (tipX - baseX) * progress
                    let reach = (1 - progress * 0.5) * halfHeight
                    let branch = NSBezierPath()
                    branch.move(to: NSPoint(x: x, y: 0))
                    branch.line(to: NSPoint(x: x + width * 0.095, y: reach * 0.7))
                    branch.move(to: NSPoint(x: x, y: 0))
                    branch.line(to: NSPoint(x: x + width * 0.075, y: -reach * 0.64))
                    branch.lineWidth = 0.38
                    branch.lineCapStyle = .round
                    veinColor.withAlphaComponent(0.52 * leafOpacity).setStroke()
                    branch.stroke()
                }
            }

            if leaf.depth > 0.62 {
                let rimLight = NSBezierPath()
                rimLight.move(to: NSPoint(x: baseX + width * 0.08, y: halfHeight * 0.16))
                rimLight.curve(
                    to: NSPoint(x: tipX - width * 0.12, y: halfHeight * 0.08),
                    controlPoint1: NSPoint(x: -width * 0.08, y: halfHeight * 0.86),
                    controlPoint2: NSPoint(x: width * 0.3, y: halfHeight * 0.7)
                )
                (baseColor.blended(withFraction: 0.55, of: .white) ?? baseColor)
                    .withAlphaComponent((0.18 + leaf.depth * 0.12) * leafOpacity)
                    .setStroke()
                rimLight.lineWidth = 0.9
                rimLight.lineCapStyle = .round
                rimLight.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawAstralMotes() {
        guard !astralParticles.isEmpty else { return }
        let visibleMotes = astralParticles.motes
            .filter(\.isVisible)
            .sorted { $0.depth < $1.depth }

        for mote in visibleMotes {
            let point = mote.renderedPosition
            let opacity = mote.opacity * (0.4 + mote.depth * 0.6)
            let size = mote.size
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: point.x, yBy: point.y)
            transform.rotate(byDegrees: mote.rotation)
            transform.concat()

            switch mote.kind {
            case .spore:
                let color = NSColor(calibratedRed: 0.38, green: 0.95, blue: 0.76, alpha: 1)
                color.withAlphaComponent(0.1 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -size * 1.9, y: -size * 1.9, width: size * 3.8, height: size * 3.8)).fill()
                color.withAlphaComponent(0.88 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -size * 0.5, y: -size * 0.5, width: size, height: size)).fill()
                NSColor.white.withAlphaComponent(0.68 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -size * 0.18, y: 0, width: size * 0.34, height: size * 0.34)).fill()

            case .stardust:
                let color = NSColor(calibratedRed: 1, green: 0.69, blue: 0.25, alpha: 1)
                color.withAlphaComponent(0.1 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -size * 1.5, y: -size * 1.5, width: size * 3, height: size * 3)).fill()
                let diamond = NSBezierPath()
                diamond.move(to: NSPoint(x: 0, y: size))
                diamond.line(to: NSPoint(x: size * 0.46, y: 0))
                diamond.line(to: NSPoint(x: 0, y: -size))
                diamond.line(to: NSPoint(x: -size * 0.46, y: 0))
                diamond.close()
                color.withAlphaComponent(0.86 * opacity).setFill()
                diamond.fill()
                NSColor(calibratedWhite: 1, alpha: 0.48 * opacity).setStroke()
                let cross = NSBezierPath()
                cross.move(to: NSPoint(x: -size * 0.75, y: 0))
                cross.line(to: NSPoint(x: size * 0.75, y: 0))
                cross.lineWidth = 0.35
                cross.stroke()

            case .ember:
                let color = NSColor(calibratedRed: 1, green: 0.24, blue: 0.18, alpha: 1)
                color.withAlphaComponent(0.1 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -size * 1.6, y: -size * 2.1, width: size * 3.2, height: size * 4.2)).fill()
                let tail = NSBezierPath()
                tail.move(to: NSPoint(x: 0, y: -size * 2.2))
                tail.line(to: NSPoint(x: 0, y: size * 0.75))
                tail.lineCapStyle = .round
                tail.lineWidth = max(0.45, size * 0.28)
                color.withAlphaComponent(0.72 * opacity).setStroke()
                tail.stroke()
                NSColor(calibratedRed: 1, green: 0.72, blue: 0.4, alpha: 0.9 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -size * 0.32, y: -size * 0.32, width: size * 0.64, height: size * 0.64)).fill()

            case .frost:
                let color = NSColor(calibratedRed: 0.76, green: 0.88, blue: 0.96, alpha: 1)
                color.withAlphaComponent(0.08 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -size * 1.6, y: -size * 1.6, width: size * 3.2, height: size * 3.2)).fill()
                color.withAlphaComponent(0.78 * opacity).setStroke()
                for arm in 0..<6 {
                    let angle = CGFloat(arm) * .pi / 3
                    let direction = NSPoint(x: cos(angle), y: sin(angle))
                    let crystal = NSBezierPath()
                    crystal.move(to: .zero)
                    crystal.line(to: NSPoint(x: direction.x * size, y: direction.y * size))
                    crystal.lineCapStyle = .round
                    crystal.lineWidth = 0.42 + mote.depth * 0.28
                    crystal.stroke()
                }
                NSColor.white.withAlphaComponent(0.72 * opacity).setFill()
                NSBezierPath(ovalIn: NSRect(x: -0.6, y: -0.6, width: 1.2, height: 1.2)).fill()
            }

            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawBeaconBirds() {
        guard !beaconParticles.isEmpty else { return }
        let visibleBirds = beaconParticles.birds
            .filter(\.isVisible)
            .sorted { $0.depth < $1.depth }

        for bird in visibleBirds {
            let point = bird.renderedPosition
            let opacity = bird.opacity * (0.42 + bird.depth * 0.58)
            let size = bird.size
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: point.x, yBy: point.y)
            transform.rotate(byDegrees: bird.bank)
            transform.concat()

            let color: NSColor
            let coreColor: NSColor
            switch bird.kind {
            case .azure:
                color = NSColor(calibratedRed: 0.52, green: 0.9, blue: 1, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.43, alpha: 1)
            case .golden:
                color = NSColor(calibratedRed: 1, green: 0.66, blue: 0.18, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.35, green: 0.2, blue: 0.06, alpha: 1)
            case .storm:
                color = NSColor(calibratedRed: 1, green: 0.28, blue: 0.44, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.19, green: 0.04, blue: 0.09, alpha: 1)
            case .frost:
                color = NSColor(calibratedWhite: 0.94, alpha: 1)
                coreColor = NSColor(calibratedWhite: 0.18, alpha: 1)
            }

            let wingTipY = bird.wingLift * size * 0.52
            let wingRootY = -size * 0.08
            let wings = NSBezierPath()
            wings.move(to: NSPoint(x: -size * 0.04, y: wingRootY))
            wings.curve(
                to: NSPoint(x: -size, y: wingTipY),
                controlPoint1: NSPoint(x: -size * 0.3, y: size * 0.2),
                controlPoint2: NSPoint(x: -size * 0.72, y: wingTipY + size * 0.12)
            )
            wings.move(to: NSPoint(x: size * 0.04, y: wingRootY))
            wings.curve(
                to: NSPoint(x: size, y: wingTipY),
                controlPoint1: NSPoint(x: size * 0.3, y: size * 0.2),
                controlPoint2: NSPoint(x: size * 0.72, y: wingTipY + size * 0.12)
            )
            wings.lineCapStyle = .round

            color.withAlphaComponent(0.1 * opacity).setStroke()
            wings.lineWidth = 2.4 + bird.depth * 1.1
            wings.stroke()
            coreColor.withAlphaComponent(0.78 * opacity).setStroke()
            wings.lineWidth = 0.66 + bird.depth * 0.58
            wings.stroke()
            color.withAlphaComponent(0.82 * opacity).setStroke()
            wings.lineWidth = 0.28 + bird.depth * 0.2
            wings.stroke()

            let body = NSBezierPath(
                ovalIn: NSRect(
                    x: -size * 0.24,
                    y: -size * 0.24,
                    width: size * 0.52,
                    height: size * 0.34
                )
            )
            coreColor.withAlphaComponent(0.9 * opacity).setFill()
            body.fill()

            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: -size * 0.23, y: -size * 0.09))
            beak.line(to: NSPoint(x: -size * 0.48, y: -size * 0.02))
            beak.line(to: NSPoint(x: -size * 0.23, y: size * 0.02))
            beak.close()
            color.withAlphaComponent(0.82 * opacity).setFill()
            beak.fill()

            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawMoonButterflies() {
        guard !moonButterflies.isEmpty else { return }
        let visibleButterflies = moonButterflies.butterflies
            .filter(\.isVisible)
            .sorted { $0.depth < $1.depth }

        for butterfly in visibleButterflies {
            let point = butterfly.renderedPosition
            let opacity = butterfly.opacity * (0.4 + butterfly.depth * 0.6)
            let size = butterfly.size
            let spread = butterfly.wingSpread
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: point.x, yBy: point.y)
            transform.rotate(byDegrees: butterfly.rotation)
            transform.concat()

            let wingColor: NSColor
            let highlightColor: NSColor
            let bodyColor: NSColor
            switch butterfly.kind {
            case .pearl:
                wingColor = NSColor(calibratedRed: 0.96, green: 0.69, blue: 0.86, alpha: 1)
                highlightColor = NSColor(calibratedRed: 0.96, green: 0.9, blue: 1, alpha: 1)
                bodyColor = NSColor(calibratedRed: 0.25, green: 0.12, blue: 0.29, alpha: 1)
            case .roseGold:
                wingColor = NSColor(calibratedRed: 0.92, green: 0.49, blue: 0.42, alpha: 1)
                highlightColor = NSColor(calibratedRed: 1, green: 0.79, blue: 0.68, alpha: 1)
                bodyColor = NSColor(calibratedRed: 0.28, green: 0.12, blue: 0.16, alpha: 1)
            case .garnet:
                wingColor = NSColor(calibratedRed: 0.78, green: 0.08, blue: 0.3, alpha: 1)
                highlightColor = NSColor(calibratedRed: 1, green: 0.38, blue: 0.58, alpha: 1)
                bodyColor = NSColor(calibratedRed: 0.12, green: 0.02, blue: 0.08, alpha: 1)
            case .silver:
                wingColor = NSColor(calibratedWhite: 0.32, alpha: 1)
                highlightColor = NSColor(calibratedRed: 0.92, green: 0.92, blue: 1, alpha: 1)
                bodyColor = NSColor(calibratedWhite: 0.14, alpha: 1)
            }

            let upperWings = NSBezierPath()
            upperWings.move(to: NSPoint(x: -size * 0.04, y: size * 0.04))
            upperWings.curve(
                to: NSPoint(x: -size * spread, y: size * 0.72),
                controlPoint1: NSPoint(x: -size * 0.28, y: size * 0.2),
                controlPoint2: NSPoint(x: -size * spread * 0.78, y: size * 0.76)
            )
            upperWings.curve(
                to: NSPoint(x: -size * 0.08, y: -size * 0.04),
                controlPoint1: NSPoint(x: -size * spread * 0.92, y: size * 0.24),
                controlPoint2: NSPoint(x: -size * 0.28, y: -size * 0.02)
            )
            upperWings.close()
            upperWings.move(to: NSPoint(x: size * 0.04, y: size * 0.04))
            upperWings.curve(
                to: NSPoint(x: size * spread, y: size * 0.72),
                controlPoint1: NSPoint(x: size * 0.28, y: size * 0.2),
                controlPoint2: NSPoint(x: size * spread * 0.78, y: size * 0.76)
            )
            upperWings.curve(
                to: NSPoint(x: size * 0.08, y: -size * 0.04),
                controlPoint1: NSPoint(x: size * spread * 0.92, y: size * 0.24),
                controlPoint2: NSPoint(x: size * 0.28, y: -size * 0.02)
            )
            upperWings.close()

            let lowerWings = NSBezierPath()
            lowerWings.move(to: NSPoint(x: -size * 0.05, y: -size * 0.06))
            lowerWings.curve(
                to: NSPoint(x: -size * spread * 0.72, y: -size * 0.52),
                controlPoint1: NSPoint(x: -size * 0.28, y: -size * 0.12),
                controlPoint2: NSPoint(x: -size * spread * 0.7, y: -size * 0.48)
            )
            lowerWings.curve(
                to: NSPoint(x: -size * 0.08, y: -size * 0.16),
                controlPoint1: NSPoint(x: -size * spread * 0.48, y: -size * 0.62),
                controlPoint2: NSPoint(x: -size * 0.2, y: -size * 0.2)
            )
            lowerWings.close()
            lowerWings.move(to: NSPoint(x: size * 0.05, y: -size * 0.06))
            lowerWings.curve(
                to: NSPoint(x: size * spread * 0.72, y: -size * 0.52),
                controlPoint1: NSPoint(x: size * 0.28, y: -size * 0.12),
                controlPoint2: NSPoint(x: size * spread * 0.7, y: -size * 0.48)
            )
            lowerWings.curve(
                to: NSPoint(x: size * 0.08, y: -size * 0.16),
                controlPoint1: NSPoint(x: size * spread * 0.48, y: -size * 0.62),
                controlPoint2: NSPoint(x: size * 0.2, y: -size * 0.2)
            )
            lowerWings.close()

            wingColor.withAlphaComponent(0.12 * opacity).setFill()
            let glow = NSBezierPath(
                ovalIn: NSRect(x: -size * 1.3, y: -size, width: size * 2.6, height: size * 2)
            )
            glow.fill()
            wingColor.withAlphaComponent(0.66 * opacity).setFill()
            upperWings.fill()
            wingColor.withAlphaComponent(0.48 * opacity).setFill()
            lowerWings.fill()
            highlightColor.withAlphaComponent(0.72 * opacity).setStroke()
            upperWings.lineWidth = 0.34 + butterfly.depth * 0.26
            upperWings.stroke()
            lowerWings.lineWidth = 0.28 + butterfly.depth * 0.2
            lowerWings.stroke()

            highlightColor.withAlphaComponent(0.52 * opacity).setFill()
            let leftPearl = NSBezierPath(
                ovalIn: NSRect(
                    x: -size * spread * 0.58,
                    y: size * 0.19,
                    width: size * 0.2,
                    height: size * 0.2
                )
            )
            leftPearl.fill()
            let rightPearl = NSBezierPath(
                ovalIn: NSRect(
                    x: size * spread * 0.38,
                    y: size * 0.19,
                    width: size * 0.2,
                    height: size * 0.2
                )
            )
            rightPearl.fill()

            bodyColor.withAlphaComponent(0.9 * opacity).setFill()
            NSBezierPath(
                ovalIn: NSRect(x: -size * 0.09, y: -size * 0.38, width: size * 0.18, height: size * 0.78)
            ).fill()
            NSBezierPath(
                ovalIn: NSRect(x: -size * 0.11, y: size * 0.29, width: size * 0.22, height: size * 0.22)
            ).fill()

            let antennae = NSBezierPath()
            antennae.move(to: NSPoint(x: -size * 0.04, y: size * 0.42))
            antennae.curve(
                to: NSPoint(x: -size * 0.28, y: size * 0.72),
                controlPoint1: NSPoint(x: -size * 0.08, y: size * 0.56),
                controlPoint2: NSPoint(x: -size * 0.22, y: size * 0.62)
            )
            antennae.move(to: NSPoint(x: size * 0.04, y: size * 0.42))
            antennae.curve(
                to: NSPoint(x: size * 0.28, y: size * 0.72),
                controlPoint1: NSPoint(x: size * 0.08, y: size * 0.56),
                controlPoint2: NSPoint(x: size * 0.22, y: size * 0.62)
            )
            antennae.lineCapStyle = .round
            antennae.lineWidth = 0.28
            highlightColor.withAlphaComponent(0.56 * opacity).setStroke()
            antennae.stroke()

            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawAbyssalJellyfish() {
        guard !abyssalJellyfish.isEmpty else { return }
        let visibleJellyfish = abyssalJellyfish.jellyfish
            .filter(\.isVisible)
            .sorted { $0.depth < $1.depth }

        for jellyfish in visibleJellyfish {
            let point = jellyfish.renderedPosition
            let opacity = jellyfish.opacity * (0.34 + jellyfish.depth * 0.66)
            let size = jellyfish.size * jellyfish.distanceScale
            let bellWidth = size * 1.58
            let bellHeight = size * 0.82 * jellyfish.bellCompression
            let tentacleLength = size * (1.45 + jellyfish.depth * 0.42) * jellyfish.tentacleExtension

            let baseColor: NSColor
            let highlightColor: NSColor
            let coreColor: NSColor
            switch jellyfish.kind {
            case .cyan:
                baseColor = NSColor(calibratedRed: 0.18, green: 0.78, blue: 0.9, alpha: 1)
                highlightColor = NSColor(calibratedRed: 0.7, green: 0.96, blue: 1, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.54, green: 0.45, blue: 0.92, alpha: 1)
            case .amber:
                baseColor = NSColor(calibratedRed: 0.88, green: 0.53, blue: 0.25, alpha: 1)
                highlightColor = NSColor(calibratedRed: 1, green: 0.83, blue: 0.58, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.72, green: 0.34, blue: 0.34, alpha: 1)
            case .garnet:
                baseColor = NSColor(calibratedRed: 0.65, green: 0.08, blue: 0.28, alpha: 1)
                highlightColor = NSColor(calibratedRed: 0.96, green: 0.3, blue: 0.5, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.4, green: 0.03, blue: 0.17, alpha: 1)
            case .silver:
                baseColor = NSColor(calibratedRed: 0.66, green: 0.72, blue: 0.8, alpha: 1)
                highlightColor = NSColor(calibratedRed: 0.95, green: 0.97, blue: 1, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.55, green: 0.6, blue: 0.72, alpha: 1)
            }

            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: point.x, yBy: point.y)
            transform.rotate(byDegrees: jellyfish.rotation)
            transform.concat()

            baseColor.withAlphaComponent(0.09 * opacity).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: -bellWidth * 0.78,
                    y: -tentacleLength * 0.55,
                    width: bellWidth * 1.56,
                    height: tentacleLength * 0.8 + bellHeight * 1.55
                )
            ).fill()

            let tentacles = NSBezierPath()
            tentacles.lineCapStyle = .round
            for index in 0..<7 {
                let fraction = CGFloat(index) / 6
                let startX = -bellWidth * 0.36 + fraction * bellWidth * 0.72
                let phase = jellyfish.driftPhase * 1.35 + jellyfish.tentaclePhase + CGFloat(index) * 0.74
                let curl = sin(phase) * size * (0.18 + jellyfish.depth * 0.08)
                let lowerCurl = cos(phase * 0.83) * size * 0.22
                let lengthVariation = 0.74 + CGFloat((index * 37) % 5) * 0.06
                let endY = -tentacleLength * lengthVariation
                tentacles.move(to: NSPoint(x: startX, y: 0))
                tentacles.curve(
                    to: NSPoint(x: startX + lowerCurl, y: endY),
                    controlPoint1: NSPoint(x: startX + curl, y: endY * 0.32),
                    controlPoint2: NSPoint(x: startX - curl * 0.72, y: endY * 0.72)
                )
            }
            baseColor.withAlphaComponent(0.18 * opacity).setStroke()
            tentacles.lineWidth = 1.25 + jellyfish.depth * 0.8
            tentacles.stroke()
            highlightColor.withAlphaComponent(0.56 * opacity).setStroke()
            tentacles.lineWidth = 0.3 + jellyfish.depth * 0.24
            tentacles.stroke()

            let oralArms = NSBezierPath()
            oralArms.lineCapStyle = .round
            for direction in [CGFloat(-1), CGFloat(1)] {
                let phase = jellyfish.pulsePhase * 0.58 + jellyfish.tentaclePhase + direction
                oralArms.move(to: NSPoint(x: direction * bellWidth * 0.13, y: bellHeight * 0.02))
                oralArms.curve(
                    to: NSPoint(x: direction * size * 0.16 + sin(phase) * size * 0.2, y: -tentacleLength * 0.74),
                    controlPoint1: NSPoint(x: direction * size * 0.42, y: -tentacleLength * 0.2),
                    controlPoint2: NSPoint(x: -direction * size * 0.14, y: -tentacleLength * 0.52)
                )
            }
            coreColor.withAlphaComponent(0.28 * opacity).setStroke()
            oralArms.lineWidth = 1.4 + jellyfish.depth * 0.9
            oralArms.stroke()
            highlightColor.withAlphaComponent(0.38 * opacity).setStroke()
            oralArms.lineWidth = 0.34 + jellyfish.depth * 0.3
            oralArms.stroke()

            let bell = NSBezierPath()
            bell.move(to: NSPoint(x: -bellWidth * 0.5, y: 0))
            bell.curve(
                to: NSPoint(x: bellWidth * 0.5, y: 0),
                controlPoint1: NSPoint(x: -bellWidth * 0.42, y: bellHeight * 0.9),
                controlPoint2: NSPoint(x: bellWidth * 0.42, y: bellHeight * 0.9)
            )
            bell.curve(
                to: NSPoint(x: bellWidth * 0.25, y: -bellHeight * 0.08),
                controlPoint1: NSPoint(x: bellWidth * 0.46, y: -bellHeight * 0.05),
                controlPoint2: NSPoint(x: bellWidth * 0.34, y: -bellHeight * 0.12)
            )
            bell.curve(
                to: NSPoint(x: 0, y: -bellHeight * 0.02),
                controlPoint1: NSPoint(x: bellWidth * 0.17, y: -bellHeight * 0.02),
                controlPoint2: NSPoint(x: bellWidth * 0.08, y: bellHeight * 0.02)
            )
            bell.curve(
                to: NSPoint(x: -bellWidth * 0.25, y: -bellHeight * 0.08),
                controlPoint1: NSPoint(x: -bellWidth * 0.08, y: bellHeight * 0.02),
                controlPoint2: NSPoint(x: -bellWidth * 0.17, y: -bellHeight * 0.02)
            )
            bell.curve(
                to: NSPoint(x: -bellWidth * 0.5, y: 0),
                controlPoint1: NSPoint(x: -bellWidth * 0.34, y: -bellHeight * 0.12),
                controlPoint2: NSPoint(x: -bellWidth * 0.46, y: -bellHeight * 0.05)
            )
            bell.close()

            NSGraphicsContext.saveGraphicsState()
            bell.addClip()
            NSGradient(
                starting: highlightColor.withAlphaComponent(0.52 * opacity),
                ending: baseColor.withAlphaComponent(0.18 * opacity)
            )?.draw(in: bell.bounds, angle: 90)
            NSGraphicsContext.restoreGraphicsState()
            highlightColor.withAlphaComponent(0.8 * opacity).setStroke()
            bell.lineWidth = 0.45 + jellyfish.depth * 0.32
            bell.stroke()

            let innerBell = NSBezierPath()
            for direction in [CGFloat(-1), -0.45, 0, 0.45, 1] {
                innerBell.move(to: NSPoint(x: direction * bellWidth * 0.08, y: bellHeight * 0.68))
                innerBell.curve(
                    to: NSPoint(x: direction * bellWidth * 0.34, y: 0),
                    controlPoint1: NSPoint(x: direction * bellWidth * 0.16, y: bellHeight * 0.52),
                    controlPoint2: NSPoint(x: direction * bellWidth * 0.28, y: bellHeight * 0.22)
                )
            }
            highlightColor.withAlphaComponent(0.38 * opacity).setStroke()
            innerBell.lineWidth = 0.24 + jellyfish.depth * 0.18
            innerBell.stroke()

            coreColor.withAlphaComponent(0.5 * opacity).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: -size * 0.2,
                    y: bellHeight * 0.18,
                    width: size * 0.4,
                    height: bellHeight * 0.28
                )
            ).fill()

            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawChronoforgeOrbits() {
        guard !chronoforgeOrbits.isEmpty else { return }
        let visibleOrbits = chronoforgeOrbits.orbits
            .filter(\.isVisible)
            .sorted { $0.depth < $1.depth }

        for orbit in visibleOrbits {
            let point = orbit.renderedPosition
            let opacity = orbit.opacity * (0.38 + orbit.depth * 0.62)
            let size = orbit.size * orbit.distanceScale * orbit.pulse

            let baseColor: NSColor
            let highlightColor: NSColor
            let coreColor: NSColor
            switch orbit.kind {
            case .verdigris:
                baseColor = NSColor(calibratedRed: 0.2, green: 0.78, blue: 0.67, alpha: 1)
                highlightColor = NSColor(calibratedRed: 0.72, green: 1, blue: 0.9, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.13, green: 0.38, blue: 0.48, alpha: 1)
            case .brass:
                baseColor = NSColor(calibratedRed: 0.82, green: 0.5, blue: 0.18, alpha: 1)
                highlightColor = NSColor(calibratedRed: 1, green: 0.84, blue: 0.48, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.46, green: 0.21, blue: 0.08, alpha: 1)
            case .cinnabar:
                baseColor = NSColor(calibratedRed: 0.8, green: 0.12, blue: 0.08, alpha: 1)
                highlightColor = NSColor(calibratedRed: 1, green: 0.48, blue: 0.27, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.34, green: 0.02, blue: 0.03, alpha: 1)
            case .silver:
                baseColor = NSColor(calibratedRed: 0.68, green: 0.74, blue: 0.82, alpha: 1)
                highlightColor = NSColor(calibratedRed: 0.98, green: 0.98, blue: 1, alpha: 1)
                coreColor = NSColor(calibratedRed: 0.32, green: 0.35, blue: 0.43, alpha: 1)
            }

            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: point.x, yBy: point.y)
            transform.rotate(byDegrees: orbit.rotation)
            transform.concat()

            baseColor.withAlphaComponent(0.1 * opacity).setFill()
            NSBezierPath(
                ovalIn: NSRect(x: -size * 1.65, y: -size * 1.3, width: size * 3.3, height: size * 2.6)
            ).fill()

            for ringIndex in 0..<3 {
                NSGraphicsContext.saveGraphicsState()
                let ringRotation = NSAffineTransform()
                let direction: CGFloat = ringIndex == 1 ? -1 : 1
                ringRotation.rotate(byDegrees: (orbit.ringPhase * 180 / .pi) * direction + CGFloat(ringIndex) * 58)
                ringRotation.concat()

                let radius = size * (0.78 + CGFloat(ringIndex) * 0.23)
                let flattening = max(0.3, orbit.ringTilt - CGFloat(ringIndex) * 0.08)
                let ring = NSBezierPath(
                    ovalIn: NSRect(
                        x: -radius,
                        y: -radius * flattening,
                        width: radius * 2,
                        height: radius * flattening * 2
                    )
                )
                ring.lineWidth = 0.3 + orbit.depth * 0.28
                if orbit.kind == .cinnabar && ringIndex == 2 {
                    var dash: [CGFloat] = [2.1, 1.5]
                    ring.setLineDash(&dash, count: dash.count, phase: orbit.ringPhase)
                } else if orbit.kind == .silver && ringIndex == 1 {
                    var dash: [CGFloat] = [1.2, 1.8]
                    ring.setLineDash(&dash, count: dash.count, phase: orbit.ringPhase * 0.5)
                }
                highlightColor.withAlphaComponent((0.46 - CGFloat(ringIndex) * 0.07) * opacity).setStroke()
                ring.stroke()

                if ringIndex == 2 && orbit.depth > 0.35 {
                    let ticks = NSBezierPath()
                    ticks.lineCapStyle = .round
                    for tickIndex in 0..<12 {
                        let angle = CGFloat(tickIndex) / 12 * 2 * .pi
                        let outerX = cos(angle) * radius
                        let outerY = sin(angle) * radius * flattening
                        let innerX = cos(angle) * radius * 0.86
                        let innerY = sin(angle) * radius * flattening * 0.86
                        ticks.move(to: NSPoint(x: innerX, y: innerY))
                        ticks.line(to: NSPoint(x: outerX, y: outerY))
                    }
                    baseColor.withAlphaComponent(0.55 * opacity).setStroke()
                    ticks.lineWidth = 0.22 + orbit.depth * 0.14
                    ticks.stroke()
                }
                NSGraphicsContext.restoreGraphicsState()
            }

            let coreRect = NSRect(x: -size * 0.42, y: -size * 0.42, width: size * 0.84, height: size * 0.84)
            let core = NSBezierPath(ovalIn: coreRect)
            NSGraphicsContext.saveGraphicsState()
            core.addClip()
            NSGradient(
                starting: highlightColor.withAlphaComponent(0.86 * opacity),
                ending: coreColor.withAlphaComponent(0.9 * opacity)
            )?.draw(in: coreRect, angle: -56)
            NSGraphicsContext.restoreGraphicsState()
            highlightColor.withAlphaComponent(0.86 * opacity).setStroke()
            core.lineWidth = 0.42 + orbit.depth * 0.24
            core.stroke()

            let hand = NSBezierPath()
            hand.lineCapStyle = .round
            hand.move(to: .zero)
            hand.line(to: NSPoint(
                x: cos(orbit.ringPhase * 1.42) * size * 0.29,
                y: sin(orbit.ringPhase * 1.42) * size * 0.29
            ))
            hand.move(to: .zero)
            hand.line(to: NSPoint(
                x: cos(-orbit.ringPhase * 0.74 + 1.1) * size * 0.2,
                y: sin(-orbit.ringPhase * 0.74 + 1.1) * size * 0.2
            ))
            highlightColor.withAlphaComponent(0.82 * opacity).setStroke()
            hand.lineWidth = 0.38 + orbit.depth * 0.2
            hand.stroke()

            let satelliteRadius = size * 1.22
            let satellitePoint = NSPoint(
                x: cos(orbit.satellitePhase) * satelliteRadius,
                y: sin(orbit.satellitePhase) * satelliteRadius * orbit.ringTilt
            )
            baseColor.withAlphaComponent(0.16 * opacity).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: satellitePoint.x - size * 0.3,
                    y: satellitePoint.y - size * 0.3,
                    width: size * 0.6,
                    height: size * 0.6
                )
            ).fill()
            highlightColor.withAlphaComponent(0.9 * opacity).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: satellitePoint.x - size * 0.105,
                    y: satellitePoint.y - size * 0.105,
                    width: size * 0.21,
                    height: size * 0.21
                )
            ).fill()

            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func updateRainAnimationState() {
        let shouldAnimate = weatherRainRequested
            && cardPresentationActive
            && !isStashed
            && snapshot != nil
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        guard shouldAnimate else {
            rainEffectView.setAnimating(false)
            return
        }

        rainEffectView.setAnimating(true)
    }

    private func updateSnowAnimationState() {
        let shouldAnimate = snowEffectRequested
            && cardPresentationActive
            && !isStashed
            && snapshot != nil
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        snowEffectView.setAnimating(shouldAnimate)
    }

    private func drawLeafSprite(_ leaf: FallingLeaf, image: NSImage) {
        let departure = leaf.departureProgress(in: bounds.height)
        let departureOpacity = CGFloat(pow(Double(1 - departure), 1.18))
        let baseOpacity = leaf.opacity * (0.54 + leaf.depth * 0.46) * departureOpacity
        let speed = max(1, hypot(leaf.velocity.dx, leaf.velocity.dy))
        let trail = CGVector(
            dx: -leaf.velocity.dx / speed * leaf.motionTrail,
            dy: -leaf.velocity.dy / speed * leaf.motionTrail
        )

        switch leaf.focus {
        case .crisp:
            drawLeafSpritePass(
                leaf,
                image: image,
                offset: .zero,
                opacity: 0.92 * baseOpacity,
                castsShadow: true
            )
        case .soft:
            drawLeafSpritePass(
                leaf,
                image: image,
                offset: .zero,
                opacity: 0.76 * baseOpacity,
                castsShadow: false
            )
        case .motion:
            let trailFractions: [CGFloat] = [1, 0.72, 0.46, 0.22]
            let trailOpacities: [CGFloat] = [0.09, 0.115, 0.145, 0.175]
            for (fraction, opacity) in zip(trailFractions, trailOpacities) {
                drawLeafSpritePass(
                    leaf,
                    image: image,
                    offset: NSSize(width: trail.dx * fraction, height: trail.dy * fraction),
                    opacity: opacity * baseOpacity,
                    castsShadow: false
                )
            }
            drawLeafSpritePass(
                leaf,
                image: image,
                offset: .zero,
                opacity: 0.36 * baseOpacity,
                castsShadow: false
            )
        }
    }

    private func drawLeafSpritePass(
        _ leaf: FallingLeaf,
        image: NSImage,
        offset: NSSize,
        opacity: CGFloat,
        castsShadow: Bool
    ) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: leaf.renderedX + offset.width, yBy: leaf.position.y + offset.height)
        transform.rotate(byDegrees: leaf.rotation)
        let flutterScale = 0.32 + abs(cos(leaf.swayPhase * 0.76)) * 0.68
        let departure = leaf.departureProgress(in: bounds.height)
        let depthScale = (0.72 + leaf.depth * 0.56) * (1 - departure * 0.46)
        transform.scaleX(by: flutterScale * depthScale, yBy: depthScale)
        transform.concat()

        if castsShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.18 * leaf.opacity * (1 - departure))
            shadow.shadowBlurRadius = 0.75
            shadow.shadowOffset = NSSize(width: 0.35, height: -0.45)
            shadow.set()
        }

        let naturalSize = image.size
        let aspect = naturalSize.width / max(1, naturalSize.height)
        let targetHeight = leaf.size
        let targetWidth = targetHeight * aspect
        image.draw(
            in: NSRect(x: -targetWidth / 2, y: -targetHeight / 2, width: targetWidth, height: targetHeight),
            from: .zero,
            operation: .sourceOver,
            fraction: opacity,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private func leafPalette(for theme: QuotaTheme) -> [NSColor] {
        switch theme {
        case .forest:
            return [
                NSColor(calibratedRed: 0.4, green: 0.78, blue: 0.43, alpha: 1),
                NSColor(calibratedRed: 0.55, green: 0.86, blue: 0.5, alpha: 1),
                NSColor(calibratedRed: 0.28, green: 0.66, blue: 0.36, alpha: 1)
            ]
        case .autumn:
            return [
                NSColor(calibratedRed: 1, green: 0.64, blue: 0.18, alpha: 1),
                NSColor(calibratedRed: 0.82, green: 0.32, blue: 0.08, alpha: 1),
                NSColor(calibratedRed: 0.96, green: 0.44, blue: 0.1, alpha: 1)
            ]
        case .apocalypse:
            return [
                NSColor(calibratedRed: 0.7, green: 0.18, blue: 0.14, alpha: 1),
                NSColor(calibratedRed: 0.58, green: 0.52, blue: 0.43, alpha: 1),
                NSColor(calibratedRed: 0.86, green: 0.3, blue: 0.18, alpha: 1)
            ]
        case .wasteland:
            return [
                NSColor(calibratedRed: 0.76, green: 0.72, blue: 0.62, alpha: 1),
                NSColor(calibratedRed: 0.54, green: 0.51, blue: 0.45, alpha: 1),
                NSColor(calibratedRed: 0.86, green: 0.82, blue: 0.72, alpha: 1)
            ]
        }
    }

    private var currentTheme: QuotaTheme {
        snapshot.map { QuotaTheme.select(for: $0.remainingPercent) } ?? .forest
    }

    private var currentBorderColor: NSColor {
        let accent = currentTheme.borderAccent
        return (accent.blended(withFraction: 0.12, of: .black) ?? accent)
            .withAlphaComponent(0.80)
    }

    private func drawEnvironment(in rect: NSRect) {
        if let image = ThemeBackgroundStore.shared.image(for: currentTheme) {
            drawBackgroundImage(image, in: rect)
            return
        }
        switch currentTheme {
        case .forest: drawForest(in: rect)
        case .autumn: drawAutumn(in: rect)
        case .apocalypse: drawApocalypse(in: rect)
        case .wasteland: drawWasteland(in: rect)
        }
    }

    private func drawBackgroundImage(_ image: NSImage, in rect: NSRect) {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return }
        let targetAspect = rect.width / rect.height
        let sourceAspect = sourceSize.width / sourceSize.height
        var sourceRect = NSRect(origin: .zero, size: sourceSize)

        if sourceAspect > targetAspect {
            sourceRect.size.width = sourceSize.height * targetAspect
            sourceRect.origin.x = isExpanded
                ? max(0, sourceSize.width - sourceRect.width)
                : (sourceSize.width - sourceRect.width) / 2
        } else if sourceAspect < targetAspect {
            sourceRect.size.height = sourceSize.width / targetAspect
            sourceRect.origin.y = (sourceSize.height - sourceRect.height) / 2
        }

        image.draw(
            in: rect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private func drawForest(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.025, green: 0.09, blue: 0.08, alpha: 1),
            ending: NSColor(calibratedRed: 0.08, green: 0.27, blue: 0.19, alpha: 1)
        )?.draw(in: rect, angle: 12)

        let beam = NSBezierPath()
        beam.move(to: NSPoint(x: rect.maxX * 0.82, y: rect.maxY))
        beam.line(to: NSPoint(x: rect.maxX * 0.48, y: 0))
        beam.line(to: NSPoint(x: rect.maxX * 0.76, y: 0))
        beam.close()
        NSColor(calibratedRed: 0.56, green: 0.95, blue: 0.66, alpha: 0.09).setFill()
        beam.fill()

        drawTrunks(in: rect, color: NSColor(calibratedRed: 0.025, green: 0.08, blue: 0.06, alpha: 0.9), count: 7)
        drawCanopy(in: rect, color: NSColor(calibratedRed: 0.06, green: 0.2, blue: 0.12, alpha: 0.95), autumn: false)
    }

    private func drawAutumn(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.12, green: 0.055, blue: 0.035, alpha: 1),
            ending: NSColor(calibratedRed: 0.47, green: 0.25, blue: 0.09, alpha: 1)
        )?.draw(in: rect, angle: 18)

        let glowRect = NSRect(x: rect.maxX - 62, y: rect.maxY - 55, width: 42, height: 42)
        NSColor(calibratedRed: 1, green: 0.69, blue: 0.25, alpha: 0.12).setFill()
        NSBezierPath(ovalIn: glowRect).fill()
        drawTrunks(in: rect, color: NSColor(calibratedRed: 0.12, green: 0.055, blue: 0.025, alpha: 0.88), count: 6)
        drawCanopy(in: rect, color: NSColor(calibratedRed: 0.65, green: 0.3, blue: 0.07, alpha: 0.86), autumn: true)
    }

    private func drawApocalypse(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.055, green: 0.045, blue: 0.055, alpha: 1),
            ending: NSColor(calibratedRed: 0.47, green: 0.09, blue: 0.07, alpha: 1)
        )?.draw(in: rect, angle: 24)

        NSColor(calibratedRed: 0.04, green: 0.035, blue: 0.04, alpha: 0.94).setFill()
        let horizon = NSBezierPath()
        horizon.move(to: .zero)
        horizon.line(to: NSPoint(x: 0, y: rect.height * 0.24))
        horizon.line(to: NSPoint(x: 28, y: rect.height * 0.3))
        horizon.line(to: NSPoint(x: 48, y: rect.height * 0.25))
        horizon.line(to: NSPoint(x: 72, y: rect.height * 0.38))
        horizon.line(to: NSPoint(x: 88, y: rect.height * 0.27))
        horizon.line(to: NSPoint(x: 116, y: rect.height * 0.42))
        horizon.line(to: NSPoint(x: 129, y: rect.height * 0.21))
        horizon.line(to: NSPoint(x: 151, y: rect.height * 0.34))
        horizon.line(to: NSPoint(x: 169, y: rect.height * 0.28))
        horizon.line(to: NSPoint(x: rect.maxX, y: rect.height * 0.4))
        horizon.line(to: NSPoint(x: rect.maxX, y: 0))
        horizon.close()
        horizon.fill()

        NSColor(calibratedRed: 1, green: 0.36, blue: 0.22, alpha: 0.1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 150, y: rect.maxY - 49, width: 32, height: 32)).fill()
    }

    private func drawWasteland(in rect: NSRect) {
        NSGradient(
            starting: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.125, alpha: 1),
            ending: NSColor(calibratedRed: 0.42, green: 0.4, blue: 0.37, alpha: 1)
        )?.draw(in: rect, angle: 16)

        NSColor(calibratedWhite: 0.08, alpha: 0.8).setFill()
        let ruins: [NSRect] = [
            NSRect(x: 112, y: 0, width: 22, height: rect.height * 0.33),
            NSRect(x: 137, y: 0, width: 16, height: rect.height * 0.48),
            NSRect(x: 157, y: 0, width: 28, height: rect.height * 0.27)
        ]
        ruins.forEach { NSBezierPath(rect: $0).fill() }

        let branch = NSBezierPath()
        branch.move(to: NSPoint(x: 188, y: 4))
        branch.curve(to: NSPoint(x: 168, y: rect.height * 0.72), controlPoint1: NSPoint(x: 183, y: rect.height * 0.35), controlPoint2: NSPoint(x: 174, y: rect.height * 0.58))
        branch.move(to: NSPoint(x: 174, y: rect.height * 0.55))
        branch.line(to: NSPoint(x: 186, y: rect.height * 0.7))
        NSColor(calibratedWhite: 0.08, alpha: 0.72).setStroke()
        branch.lineWidth = 3
        branch.stroke()
    }

    private func drawTrunks(in rect: NSRect, color: NSColor, count: Int) {
        color.setFill()
        for index in 0..<count {
            let x = rect.width * 0.54 + CGFloat(index) * rect.width * 0.075
            let width = CGFloat(5 + (index % 3) * 2)
            NSBezierPath(rect: NSRect(x: x, y: 0, width: width, height: rect.height)).fill()
        }
    }

    private func drawCanopy(in rect: NSRect, color: NSColor, autumn: Bool) {
        let points: [(CGFloat, CGFloat, CGFloat)] = [
            (0.55, 0.78, 0.2), (0.7, 0.9, 0.23), (0.86, 0.75, 0.22),
            (0.98, 0.92, 0.25), (0.62, 0.56, 0.16), (0.83, 0.5, 0.18)
        ]
        for (index, point) in points.enumerated() {
            let diameter = rect.width * point.2
            let leafColor: NSColor
            if autumn {
                leafColor = index.isMultiple(of: 2)
                    ? color
                    : NSColor(calibratedRed: 0.88, green: 0.46, blue: 0.09, alpha: 0.55)
            } else {
                leafColor = color
            }
            leafColor.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: rect.width * point.0 - diameter / 2,
                y: rect.height * point.1 - diameter / 2,
                width: diameter,
                height: diameter
            )).fill()
        }
    }

    private func drawReadabilityOverlay(in rect: NSRect) {
        NSGradient(colors: [
            NSColor(calibratedWhite: 0, alpha: 0.58),
            NSColor(calibratedWhite: 0, alpha: 0.1),
            NSColor(calibratedWhite: 0, alpha: 0.36)
        ])?.draw(in: rect, angle: 0)
        NSColor(calibratedWhite: 0, alpha: isExpanded ? 0.13 : 0.06).setFill()
        NSBezierPath(rect: rect).fill()
    }

    private func drawSummary() {
        let top = bounds.maxY
        let leftInset: CGFloat = 15
        let contentRight: CGFloat = 185
        let title = snapshot?.windowTitle ?? AppText.sevenDayQuota
        let titleFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let titleColor = NSColor.white.withAlphaComponent(0.96)
        drawText(title, at: NSPoint(x: leftInset, y: top - 31), font: titleFont, color: titleColor)

        let titleWidth = (title as NSString).size(withAttributes: [.font: titleFont]).width
        let markX = leftInset + titleWidth + 4
        drawCodexIcon(at: NSPoint(x: markX, y: top - 29.5), size: 15)

        let percent = snapshot.map { "\($0.roundedRemaining)%" } ?? "--%"
        let percentFont = NSFont.monospacedDigitSystemFont(ofSize: 23, weight: .bold)

        let resetText = summaryResetText()
        drawText(resetText, at: NSPoint(x: leftInset, y: top - 48), font: .systemFont(ofSize: 10.5, weight: .medium), color: .white.withAlphaComponent(0.62))

        drawText(percent, at: NSPoint(x: contentRight, y: top - 39), font: percentFont, color: .white, alignment: .right)
        drawText(AppText.remaining, at: NSPoint(x: contentRight, y: top - 49), font: .systemFont(ofSize: 9.5, weight: .medium), color: .white.withAlphaComponent(0.62), alignment: .right)

        let barRect = NSRect(x: leftInset, y: top - 68, width: contentRight - leftInset, height: 5)
        let track = NSBezierPath(roundedRect: barRect, xRadius: 2.5, yRadius: 2.5)
        NSColor(calibratedWhite: 0, alpha: 0.42).setFill()
        track.fill()

        guard let snapshot else { return }
        let width = max(snapshot.remainingPercent > 0 ? 3 : 0, barRect.width * CGFloat(snapshot.remainingPercent / 100))
        guard width > 0 else { return }
        let fillRect = NSRect(x: barRect.minX, y: barRect.minY, width: width, height: barRect.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        NSGraphicsContext.saveGraphicsState()
        fill.addClip()
        let accent = currentTheme.progressAccent
        let leading = accent.blended(withFraction: 0.50, of: .black) ?? accent
        let middle = accent.blended(withFraction: 0.22, of: .black) ?? accent
        let trailing = accent.blended(withFraction: 0.04, of: .black) ?? accent
        NSGradient(colors: [leading, middle, trailing])?.draw(in: fillRect, angle: 0)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawDetails() {
        let top = bounds.maxY
        NSColor.white.withAlphaComponent(0.16).setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: 15, y: top - 83))
        divider.line(to: NSPoint(x: 185, y: top - 83))
        divider.lineWidth = 1
        divider.stroke()

        let labelColor = NSColor.white.withAlphaComponent(0.56)
        let valueColor = NSColor.white.withAlphaComponent(0.92)
        let font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)

        let rows: [(String, String, CGFloat)] = [
            (AppText.sevenDayQuota, snapshot.map { AppText.quotaUsage(remaining: $0.roundedRemaining, used: $0.roundedUsed) } ?? "--", top - 104),
            (AppText.timeToReset, exactResetText(), top - 125),
            (AppText.subscriptionPlan, snapshot?.readablePlan ?? "--", top - 146),
            (AppText.dataUpdated, dataAgeText(), top - 167)
        ]

        for row in rows {
            drawText(row.0, at: NSPoint(x: 15, y: row.2), font: font, color: labelColor)
            drawText(row.1, at: NSPoint(x: 185, y: row.2), font: valueFont, color: valueColor, alignment: .right)
        }
    }

    private func drawCodexIcon(at point: NSPoint, size: CGFloat) {
        guard let codexIcon else {
            drawFallbackMark(at: point, size: size)
            return
        }

        let iconRect = NSRect(x: point.x, y: point.y, width: size, height: size)
        let roundedClip = NSBezierPath(
            roundedRect: iconRect,
            xRadius: size * 0.24,
            yRadius: size * 0.24
        )
        NSGraphicsContext.saveGraphicsState()
        roundedClip.addClip()
        codexIcon.draw(
            in: iconRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawFallbackMark(at point: NSPoint, size: CGFloat) {
        let stroke = NSColor.white.withAlphaComponent(0.92)
        stroke.setStroke()

        let prompt = NSBezierPath()
        prompt.move(to: NSPoint(x: point.x, y: point.y + size * 0.24))
        prompt.line(to: NSPoint(x: point.x + size * 0.28, y: point.y + size * 0.5))
        prompt.line(to: NSPoint(x: point.x, y: point.y + size * 0.76))
        prompt.lineWidth = 1.4
        prompt.lineCapStyle = .round
        prompt.lineJoinStyle = .round
        prompt.stroke()

        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: point.x + size * 0.45, y: point.y + size * 0.2))
        leaf.curve(
            to: NSPoint(x: point.x + size * 0.86, y: point.y + size * 0.82),
            controlPoint1: NSPoint(x: point.x + size * 0.82, y: point.y + size * 0.22),
            controlPoint2: NSPoint(x: point.x + size * 0.92, y: point.y + size * 0.56)
        )
        leaf.curve(
            to: NSPoint(x: point.x + size * 0.45, y: point.y + size * 0.2),
            controlPoint1: NSPoint(x: point.x + size * 0.64, y: point.y + size * 0.77),
            controlPoint2: NSPoint(x: point.x + size * 0.45, y: point.y + size * 0.49)
        )
        leaf.lineWidth = 1.2
        leaf.stroke()
    }

    private enum TextAlignment { case left, right }

    private func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, alignment: TextAlignment = .left) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = alignment == .right ? NSPoint(x: point.x - size.width, y: point.y) : point
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    private func summaryResetText() -> String {
        guard let snapshot else { return AppText.waitingForQuota }
        return resetComponents(until: snapshot.resetsAt, includeResetPrefix: true)
    }

    private func exactResetText() -> String {
        guard let snapshot else { return "--" }
        return resetComponents(until: snapshot.resetsAt, includeResetPrefix: false)
    }

    private func resetComponents(until date: Date?, includeResetPrefix: Bool) -> String {
        guard let date else { return AppText.resetTimeUnknown }
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds == 0 { return AppText.resettingSoon }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = max(1, (seconds % 3_600) / 60)
        return AppText.resetCountdown(days: days, hours: hours, minutes: minutes, includeResetPrefix: includeResetPrefix)
    }

    private func dataAgeText() -> String {
        guard let snapshot else { return "--" }
        let seconds = max(0, Int(Date().timeIntervalSince(snapshot.fetchedAt)))
        return AppText.dataAge(seconds: seconds)
    }

    private func updateAccessibility() {
        let title = snapshot?.windowTitle ?? AppText.sevenDayQuota
        let state = snapshot.map { QuotaTheme.select(for: $0.remainingPercent).accessibilityName } ?? AppText.noData
        setAccessibilityLabel(AppText.accessibilityLabel(
            title: title,
            remainingPercent: snapshot?.roundedRemaining,
            theme: state,
            isStashed: isStashed,
            isExpanded: isExpanded
        ))
        setAccessibilityValue(snapshot?.remainingPercent as NSNumber?)
        setAccessibilityHelp(AppText.accessibilityHelp)
    }
}
