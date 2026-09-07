import AppKit
import UniformTypeIdentifiers

final class CardWindowController: NSWindowController, QuotaCardViewDelegate {
    static let cardWidth: CGFloat = 200
    static let collapsedHeight: CGFloat = 80
    static let expandedHeight: CGFloat = 178
    static let stashedWidth: CGFloat = 16
    static let safeInset: CGFloat = 20

    var onRefresh: (() -> Void)?
    var onWeatherLinkToggle: ((Bool) -> Void)?

    private let panel: CardPanel
    private let cardView: QuotaCardView
    private let defaults: UserDefaults
    private var isExpanded: Bool
    private var edgeSide: StashedEdge?
    private var fullFrame: NSRect
    private var isDragging = false
    private var pendingRestash: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private var weatherLinkEnabled = false
    private var weatherLinkStatus: WeatherLinkStatus = .disabled

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isExpanded = defaults.object(forKey: "QuotaGrove.expanded") as? Bool ?? false
        let height = self.isExpanded ? Self.expandedHeight : Self.collapsedHeight
        let initial = Self.restoredFrame(defaults: defaults, height: height)
        self.fullFrame = initial
        self.panel = CardPanel(contentRect: initial)
        self.cardView = QuotaCardView(frame: NSRect(origin: .zero, size: initial.size))
        super.init(window: panel)

        panel.contentView = cardView
        cardView.autoresizingMask = [.width, .height]
        cardView.delegate = self
        cardView.isExpanded = isExpanded

        if let rawSide = defaults.string(forKey: "QuotaGrove.edgeSide"), let side = StashedEdge(rawValue: rawSide) {
            edgeSide = side
            stash(to: side, animated: false, preserveFullFrame: true)
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.screenConfigurationDidChange()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    func setSnapshot(_ snapshot: QuotaSnapshot?) {
        let snapshotChanged = cardView.snapshot != snapshot
        if snapshotChanged { cardView.snapshot = snapshot }
        if snapshotChanged, cardView.isStashed, let side = edgeSide {
            stash(to: side, animated: false, preserveFullFrame: true)
        }
    }

    func refreshClock() {
        cardView.refreshClock()
    }

    func setWeatherRainActive(_ active: Bool) {
        cardView.setWeatherRainActive(active)
    }

    func setSnowEffectActive(_ active: Bool) {
        cardView.setSnowEffectActive(active)
    }

    func setWeatherEffect(_ effect: WeatherEffect) {
        cardView.setWeatherEffect(effect)
    }

    func setWeatherLink(enabled: Bool, status: WeatherLinkStatus) {
        weatherLinkEnabled = enabled
        weatherLinkStatus = status
    }

    func showCard() {
        panel.orderFrontRegardless()
        cardView.setCardPresentationActive(true)
        cardView.setAmbientLeafAnimationActive(true)
    }

    func hideCard() {
        cardView.setCardPresentationActive(false)
        cardView.setAmbientLeafAnimationActive(false)
        panel.orderOut(nil)
    }

    func cardViewDidSingleClick(_ view: QuotaCardView) {
        guard edgeSide == nil else { return }
        setExpanded(!isExpanded, animated: true)
    }

    func cardViewDidDoubleClick(_ view: QuotaCardView) {
        onRefresh?()
    }

    func cardView(_ view: QuotaCardView, dragTo origin: NSPoint) {
        pendingRestash?.cancel()
        isDragging = true

        if edgeSide != nil {
            edgeSide = nil
            defaults.removeObject(forKey: "QuotaGrove.edgeSide")
            cardView.isStashed = false
        }

        let height = isExpanded ? Self.expandedHeight : Self.collapsedHeight
        var target = NSRect(x: origin.x, y: origin.y, width: Self.cardWidth, height: height)
        let screen = Self.screen(containing: target) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        target.origin.x = min(max(target.origin.x, visible.minX), visible.maxX - target.width)
        target.origin.y = min(max(target.origin.y, visible.minY), visible.maxY - target.height)
        panel.setFrame(target, display: true)
        fullFrame = target
    }

    func cardViewDidEndDragging(_ view: QuotaCardView) {
        isDragging = false
        fullFrame = panel.frame
        saveFullFrame()

        guard let screen = Self.screen(containing: panel.frame) else { return }
        let visible = screen.visibleFrame
        if abs(panel.frame.minX - visible.minX) < 0.5 {
            stash(to: .left, animated: true)
        } else if abs(panel.frame.maxX - visible.maxX) < 0.5 {
            stash(to: .right, animated: true)
        }
    }

    func cardViewPointerEntered(_ view: QuotaCardView) {
        pendingRestash?.cancel()
        guard cardView.isStashed, let side = edgeSide else { return }
        reveal(from: side)
    }

    func cardViewPointerExited(_ view: QuotaCardView) {
        guard edgeSide != nil, !isDragging else { return }
        pendingRestash?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self, let side = self.edgeSide, !self.isDragging else { return }
            guard !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.stash(to: side, animated: true, preserveFullFrame: true)
        }
        pendingRestash = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: task)
    }

    func cardView(_ view: QuotaCardView, showContextMenu event: NSEvent) {
        let menu = NSMenu(title: "Quota Grove")
        menu.addItem(withTitle: AppText.refreshQuota, action: #selector(refreshFromMenu), keyEquivalent: "r").target = self

        let launchItem = menu.addItem(withTitle: AppText.launchAtLogin, action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off

        let weatherItem = menu.addItem(withTitle: AppText.followLocalWeather, action: #selector(toggleWeatherLink), keyEquivalent: "")
        weatherItem.target = self
        weatherItem.state = weatherLinkEnabled ? .on : .off
        if weatherLinkEnabled {
            let statusItem = NSMenuItem(title: AppText.weatherLinkStatus(weatherLinkStatus), action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)
        }

        menu.addItem(.separator())
        let backgroundSetItem = NSMenuItem(title: AppText.backgroundStyle, action: nil, keyEquivalent: "")
        let backgroundSetMenu = NSMenu(title: AppText.backgroundStyle)
        for style in CardBackgroundStyle.builtInStyles {
            let title: String
            switch style {
            case .quotaGrove: title = AppText.quotaGroveStyle
            case .astralTerrarium: title = AppText.astralTerrariumStyle
            case .cloudseaBeacon: title = AppText.cloudseaBeaconStyle
            case .moonlitConservatory: title = AppText.moonlitConservatoryStyle
            case .abyssalReverie: title = AppText.abyssalReverieStyle
            case .chronoforge: title = AppText.chronoforgeStyle
            case .custom: continue
            }
            let item = NSMenuItem(title: title, action: #selector(selectBackgroundStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.state = ThemeBackgroundStore.shared.selectedStyle == style ? .on : .off
            backgroundSetMenu.addItem(item)
        }
        menu.addItem(backgroundSetItem)
        menu.setSubmenu(backgroundSetMenu, for: backgroundSetItem)
        menu.addItem(withTitle: AppText.customizeBackground, action: #selector(chooseCustomBackground), keyEquivalent: "").target = self
        let restoreBackgroundItem = menu.addItem(withTitle: AppText.restoreDefaultBackground, action: #selector(restoreDefaultBackground), keyEquivalent: "")
        restoreBackgroundItem.target = self
        restoreBackgroundItem.isEnabled = ThemeBackgroundStore.shared.hasCustomBackground
            || ThemeBackgroundStore.shared.selectedStyle != .quotaGrove
        menu.addItem(.separator())
        menu.addItem(withTitle: AppText.resetCardPosition, action: #selector(resetPosition), keyEquivalent: "").target = self
        menu.addItem(withTitle: AppText.aboutAndPrivacy, action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: AppText.quit, action: #selector(quit), keyEquivalent: "q").target = self
        NSMenu.popUpContextMenu(menu, with: event, for: cardView)
    }

    @objc private func refreshFromMenu() {
        onRefresh?()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.shared.setEnabled(!LaunchAtLoginManager.shared.isEnabled)
        } catch {
            presentAlert(title: AppText.launchUpdateFailed, message: error.localizedDescription)
        }
    }

    @objc private func toggleWeatherLink() {
        onWeatherLinkToggle?(!weatherLinkEnabled)
    }

    @objc private func selectBackgroundStyle(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let style = CardBackgroundStyle(rawValue: rawValue),
            CardBackgroundStyle.builtInStyles.contains(style)
        else { return }
        ThemeBackgroundStore.shared.selectBuiltInStyle(style)
        cardView.backgroundStyleDidChange()
    }

    @objc private func chooseCustomBackground() {
        NSApp.activate(ignoringOtherApps: true)
        let openPanel = NSOpenPanel()
        openPanel.title = AppText.chooseBackgroundTitle
        openPanel.prompt = AppText.chooseBackgroundPrompt
        openPanel.allowedContentTypes = [.image]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        guard openPanel.runModal() == .OK, let sourceURL = openPanel.url else { return }
        do {
            try ThemeBackgroundStore.shared.installCustomBackground(from: sourceURL)
            cardView.backgroundStyleDidChange()
        } catch {
            presentAlert(title: AppText.customBackgroundFailed, message: error.localizedDescription)
        }
    }

    @objc private func restoreDefaultBackground() {
        do {
            try ThemeBackgroundStore.shared.restoreDefaultBackground()
            cardView.backgroundStyleDidChange()
        } catch {
            presentAlert(title: AppText.customBackgroundFailed, message: error.localizedDescription)
        }
    }

    @objc private func resetPosition() {
        edgeSide = nil
        defaults.removeObject(forKey: "QuotaGrove.edgeSide")
        let height = isExpanded ? Self.expandedHeight : Self.collapsedHeight
        let target = Self.defaultFrame(height: height)
        fullFrame = target
        cardView.isStashed = false
        animateFrame(to: target)
        saveFullFrame()
    }

    @objc private func showAbout() {
        presentAlert(
            title: AppText.aboutTitle,
            message: AppText.aboutMessage
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func presentAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: AppText.ok)
        alert.runModal()
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        defaults.set(expanded, forKey: "QuotaGrove.expanded")
        cardView.isExpanded = expanded

        let newHeight = expanded ? Self.expandedHeight : Self.collapsedHeight
        var frame = panel.frame
        frame.origin.y = frame.maxY - newHeight
        frame.size.height = newHeight
        fullFrame = frame
        animated ? animateFrame(to: frame) : panel.setFrame(frame, display: true)
        saveFullFrame()
    }

    private func stash(to side: StashedEdge, animated: Bool, preserveFullFrame: Bool = false) {
        pendingRestash?.cancel()
        if !preserveFullFrame && !cardView.isStashed { fullFrame = panel.frame }
        guard let screen = Self.screen(containing: fullFrame) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let top = min(max(fullFrame.maxY, visible.minY + Self.collapsedHeight), visible.maxY)
        let x = side == .left ? visible.minX : visible.maxX - Self.stashedWidth
        let target = NSRect(x: x, y: top - Self.collapsedHeight, width: Self.stashedWidth, height: Self.collapsedHeight)

        edgeSide = side
        defaults.set(side.rawValue, forKey: "QuotaGrove.edgeSide")
        cardView.stashedEdge = side
        cardView.isStashed = true
        animated ? animateFrame(to: target) : panel.setFrame(target, display: true)
    }

    private func reveal(from side: StashedEdge) {
        guard let screen = Self.screen(containing: panel.frame) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let height = isExpanded ? Self.expandedHeight : Self.collapsedHeight
        let top = min(max(fullFrame.maxY, visible.minY + height), visible.maxY)
        let x = side == .left ? visible.minX : visible.maxX - Self.cardWidth
        let target = NSRect(x: x, y: top - height, width: Self.cardWidth, height: height)
        cardView.isStashed = false
        animateFrame(to: target)
    }

    private func animateFrame(to frame: NSRect) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.19
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func saveFullFrame() {
        defaults.set(NSStringFromRect(fullFrame), forKey: "QuotaGrove.fullFrame")
    }

    private func screenConfigurationDidChange() {
        let height = isExpanded ? Self.expandedHeight : Self.collapsedHeight
        fullFrame.size = NSSize(width: Self.cardWidth, height: height)
        fullFrame = Self.constrainedToVisibleScreen(fullFrame) ?? Self.defaultFrame(height: height)
        saveFullFrame()
        if let edgeSide {
            stash(to: edgeSide, animated: false, preserveFullFrame: true)
        } else {
            panel.setFrame(fullFrame, display: true)
        }
    }

    private static func restoredFrame(defaults: UserDefaults, height: CGFloat) -> NSRect {
        guard let raw = defaults.string(forKey: "QuotaGrove.fullFrame") else {
            return defaultFrame(height: height)
        }
        var frame = NSRectFromString(raw)
        frame.size = NSSize(width: cardWidth, height: height)
        return constrainedToVisibleScreen(frame) ?? defaultFrame(height: height)
    }

    private static func defaultFrame(height: CGFloat) -> NSRect {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_440, height: 900)
        return NSRect(
            x: visible.maxX - cardWidth - safeInset,
            y: visible.maxY - height - safeInset,
            width: cardWidth,
            height: height
        )
    }

    private static func constrainedToVisibleScreen(_ frame: NSRect) -> NSRect? {
        guard let screen = screen(containing: frame) else { return nil }
        let visible = screen.visibleFrame
        var result = frame
        result.origin.x = min(max(result.origin.x, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.origin.y, visible.minY), visible.maxY - result.height)
        return result
    }

    private static func screen(containing frame: NSRect) -> NSScreen? {
        NSScreen.screens
            .map { ($0, $0.visibleFrame.intersection(frame).width * $0.visibleFrame.intersection(frame).height) }
            .filter { $0.1 > 0 }
            .max(by: { $0.1 < $1.1 })?
            .0
    }
}
