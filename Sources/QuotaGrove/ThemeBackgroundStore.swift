import AppKit
import ImageIO

enum ThemeBackgroundStoreError: LocalizedError {
    case invalidImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return AppText.localized("无法读取这张图片，请选择有效的 PNG、JPEG、HEIC 或其他常见图片。", "This image couldn’t be read. Choose a valid PNG, JPEG, HEIC, or another common image format.")
        case .encodingFailed:
            return AppText.localized("无法保存自定义背景图片。", "The custom background image couldn’t be saved.")
        }
    }
}

enum CardBackgroundStyle: String, CaseIterable {
    case quotaGrove
    case astralTerrarium
    case cloudseaBeacon
    case moonlitConservatory
    case abyssalReverie
    case chronoforge
    case custom

    static let builtInStyles: [CardBackgroundStyle] = [
        .quotaGrove,
        .astralTerrarium,
        .cloudseaBeacon,
        .moonlitConservatory,
        .abyssalReverie,
        .chronoforge
    ]
}

final class ThemeBackgroundStore {
    static let shared = ThemeBackgroundStore()
    static let maximumPixelDimension = 2_400
    private static let selectedStyleKey = "QuotaGrove.backgroundStyle"

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private let customBackgroundURL: URL
    private var cache: [String: NSImage] = [:]
    private var customBackgroundCache: NSImage?
    private var sessionStyleOverride: CardBackgroundStyle?

    init(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        customBackgroundURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.defaults = defaults
        if let customBackgroundURL {
            self.customBackgroundURL = customBackgroundURL
        } else {
            let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            self.customBackgroundURL = supportDirectory
                .appendingPathComponent("Quota Grove", isDirectory: true)
                .appendingPathComponent("custom-background.png")
        }
    }

    var hasCustomBackground: Bool {
        fileManager.fileExists(atPath: customBackgroundURL.path)
    }

    var selectedStyle: CardBackgroundStyle {
        if let sessionStyleOverride { return sessionStyleOverride }
        if let rawValue = defaults.string(forKey: Self.selectedStyleKey),
           let style = CardBackgroundStyle(rawValue: rawValue) {
            return style == .custom && !hasCustomBackground ? .quotaGrove : style
        }
        return hasCustomBackground ? .custom : .quotaGrove
    }

    var usesAstralEffects: Bool { selectedStyle == .astralTerrarium }
    var usesBeaconEffects: Bool { selectedStyle == .cloudseaBeacon }
    var usesMoonlitEffects: Bool { selectedStyle == .moonlitConservatory }
    var usesAbyssalEffects: Bool { selectedStyle == .abyssalReverie }
    var usesChronoforgeEffects: Bool { selectedStyle == .chronoforge }

    func image(for theme: QuotaTheme) -> NSImage? {
        let style = selectedStyle
        if style == .custom, let customBackground = customBackgroundImage() { return customBackground }
        let builtInStyle = style == .custom ? CardBackgroundStyle.quotaGrove : style
        let cacheKey = "\(builtInStyle.rawValue).\(theme.rawValue)"
        if let cached = cache[cacheKey] { return cached }
        guard let url = assetURL(for: theme, style: builtInStyle), let image = NSImage(contentsOf: url) else { return nil }
        cache[cacheKey] = image
        return image
    }

    func selectBuiltInStyle(_ style: CardBackgroundStyle) {
        guard CardBackgroundStyle.builtInStyles.contains(style) else { return }
        defaults.set(style.rawValue, forKey: Self.selectedStyleKey)
    }

    func setSessionStyleOverride(_ style: CardBackgroundStyle?) {
        if let style, !CardBackgroundStyle.builtInStyles.contains(style) { return }
        sessionStyleOverride = style
    }

    func installCustomBackground(from sourceURL: URL) throws {
        guard
            let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: Self.maximumPixelDimension
                ] as CFDictionary
            )
        else {
            throw ThemeBackgroundStoreError.invalidImage
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            throw ThemeBackgroundStoreError.encodingFailed
        }

        try fileManager.createDirectory(
            at: customBackgroundURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pngData.write(to: customBackgroundURL, options: .atomic)
        guard let image = NSImage(data: pngData) else {
            throw ThemeBackgroundStoreError.encodingFailed
        }
        customBackgroundCache = image
        defaults.set(CardBackgroundStyle.custom.rawValue, forKey: Self.selectedStyleKey)
    }

    func restoreDefaultBackground() throws {
        if hasCustomBackground {
            try fileManager.removeItem(at: customBackgroundURL)
        }
        customBackgroundCache = nil
        defaults.set(CardBackgroundStyle.quotaGrove.rawValue, forKey: Self.selectedStyleKey)
    }

    private func customBackgroundImage() -> NSImage? {
        if let customBackgroundCache { return customBackgroundCache }
        guard hasCustomBackground, let image = NSImage(contentsOf: customBackgroundURL) else { return nil }
        customBackgroundCache = image
        return image
    }

    private func assetURL(for theme: QuotaTheme, style: CardBackgroundStyle) -> URL? {
        let backgroundSetDirectory: String?
        switch style {
        case .astralTerrarium: backgroundSetDirectory = "AstralTerrarium"
        case .cloudseaBeacon: backgroundSetDirectory = "CloudseaBeacon"
        case .moonlitConservatory: backgroundSetDirectory = "MoonlitConservatory"
        case .abyssalReverie: backgroundSetDirectory = "AbyssalReverie"
        case .chronoforge: backgroundSetDirectory = "Chronoforge"
        case .quotaGrove, .custom: backgroundSetDirectory = nil
        }

        if let backgroundSetDirectory {
            let filename = "\(theme.rawValue).png"
            if let resourceURL = Bundle.main.resourceURL?
                .appendingPathComponent("BackgroundSets/\(backgroundSetDirectory)", isDirectory: true)
                .appendingPathComponent(filename),
               fileManager.fileExists(atPath: resourceURL.path) {
                return resourceURL
            }

            let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Assets/BackgroundSets/\(backgroundSetDirectory)", isDirectory: true)
                .appendingPathComponent(filename)
            return fileManager.fileExists(atPath: developmentURL.path) ? developmentURL : nil
        }

        let filename: String
        switch theme {
        case .forest: filename = "背景百分之50以上.png"
        case .autumn: filename = "背景百分之50以下.png"
        case .apocalypse: filename = "背景百分之20以下.png"
        case .wasteland: filename = "背景百分之3以下.png"
        }

        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("Backgrounds", isDirectory: true)
            .appendingPathComponent(filename),
           fileManager.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("bg", isDirectory: true)
            .appendingPathComponent(filename)
        return fileManager.fileExists(atPath: developmentURL.path) ? developmentURL : nil
    }
}
