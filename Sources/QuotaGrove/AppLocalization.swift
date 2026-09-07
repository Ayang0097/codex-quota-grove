import Foundation

enum AppLanguage: String, Equatable {
    case chinese
    case english

    static var system: AppLanguage {
        resolve(preferredLanguages: Locale.preferredLanguages)
    }

    static func resolve(preferredLanguages: [String]) -> AppLanguage {
        guard let primary = preferredLanguages.first else { return .english }
        let normalized = primary.replacingOccurrences(of: "_", with: "-").lowercased()
        return normalized == "zh" || normalized.hasPrefix("zh-") ? .chinese : .english
    }
}

enum AppText {
    static func localized(_ chinese: String, _ english: String, language: AppLanguage = .system) -> String {
        language == .chinese ? chinese : english
    }

    static func windowTitle(minutes: Int, language: AppLanguage = .system) -> String {
        if minutes == 10_080 { return localized("7 天额度", "7-day quota", language: language) }
        if minutes % 1_440 == 0 {
            let days = minutes / 1_440
            return localized("\(days) 天额度", "\(days)-day quota", language: language)
        }
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return localized("\(hours) 小时额度", "\(hours)-hour quota", language: language)
        }
        return localized("\(minutes) 分钟额度", "\(minutes)-minute quota", language: language)
    }

    static var sevenDayQuota: String { localized("7 天额度", "7-day quota") }
    static var remaining: String { localized("剩余", "Remaining") }
    static var waitingForQuota: String { localized("等待额度数据", "Waiting for quota data") }
    static var resetTimeUnknown: String { localized("重置时间未知", "Reset time unknown") }
    static var resettingSoon: String { localized("即将重置", "Resetting soon") }
    static var timeToReset: String { localized("距离重置", "Time to reset") }
    static var subscriptionPlan: String { localized("订阅计划", "Plan") }
    static var dataUpdated: String { localized("数据更新", "Updated") }
    static var noData: String { localized("暂无数据", "No data") }

    static func quotaUsage(remaining: Int, used: Int, language: AppLanguage = .system) -> String {
        localized("剩余 \(remaining)% · 已用 \(used)%", "\(remaining)% left · \(used)% used", language: language)
    }

    static func resetCountdown(days: Int, hours: Int, minutes: Int, includeResetPrefix: Bool, language: AppLanguage = .system) -> String {
        if language == .chinese {
            let value = days > 0 ? "\(days) 天 \(hours) 小时" : "\(hours) 小时 \(minutes) 分钟"
            return includeResetPrefix ? "\(value)后重置" : value
        }
        let value = days > 0 ? "\(days)d \(hours)h" : "\(hours)h \(minutes)m"
        return includeResetPrefix ? "Resets in \(value)" : value
    }

    static func dataAge(seconds: Int, language: AppLanguage = .system) -> String {
        if language == .chinese {
            switch seconds {
            case 0...4: return "刚刚"
            case 5..<60: return "\(seconds) 秒前"
            case 60..<3_600: return "\(seconds / 60) 分钟前"
            default: return "\(seconds / 3_600) 小时前"
            }
        }
        switch seconds {
        case 0...4: return "Just now"
        case 5..<60: return "\(seconds)s ago"
        case 60..<3_600: return "\(seconds / 60)m ago"
        default: return "\(seconds / 3_600)h ago"
        }
    }

    static var refreshQuota: String { localized("刷新额度", "Refresh quota") }
    static var followLocalWeather: String { localized("跟随当地天气", "Follow local weather") }
    static var backgroundStyle: String { localized("背景套系", "Background set") }
    static var quotaGroveStyle: String { localized("额度森林", "Quota Grove") }
    static var astralTerrariumStyle: String { localized("星屿生态舱", "Astral Terrarium") }
    static var cloudseaBeaconStyle: String { localized("云海灯塔", "Cloudsea Beacon") }
    static var moonlitConservatoryStyle: String { localized("月光花房", "Moonlit Conservatory") }
    static var abyssalReverieStyle: String { localized("深海幻境", "Abyssal Reverie") }
    static var chronoforgeStyle: String { localized("时间铸境", "Chronoforge") }
    static var customizeBackground: String { localized("自定义背景…", "Customize background…") }
    static var restoreDefaultBackground: String { localized("恢复默认背景", "Restore default background") }
    static var chooseBackgroundTitle: String { localized("选择卡片背景", "Choose card background") }
    static var chooseBackgroundPrompt: String { localized("选择", "Choose") }
    static var customBackgroundFailed: String { localized("无法更新背景", "Couldn’t update background") }
    static var launchAtLogin: String { localized("登录时启动", "Launch at login") }
    static var resetCardPosition: String { localized("重置卡片位置", "Reset card position") }
    static var aboutAndPrivacy: String { localized("关于与隐私", "About & privacy") }
    static var quit: String { localized("退出 Quota Grove", "Quit Quota Grove") }
    static var launchUpdateFailed: String { localized("无法更新登录启动", "Couldn’t update launch at login") }
    static var ok: String { localized("好", "OK") }
    static var aboutTitle: String { localized("Quota Grove · 额度森林", "Quota Grove") }
    static var aboutMessage: String {
        localized(
            "非官方本机工具，与 OpenAI 无隶属或背书关系。\n\n额度功能只读取本机 Codex 运行事件，不读取账号凭据，也不上传额度或日志。自定义背景图片会缩放并复制到本机应用数据目录，不会上传。\n\n“跟随当地天气”默认关闭。主动开启后，应用会通过系统定位获取当前位置，将经纬度四舍五入到两位小数后发送给 Open-Meteo，仅用于判断当地是否正在下雨或下雪。应用不包含遥测。\n\n天气数据：Open-Meteo（CC BY 4.0）\nhttps://open-meteo.com/",
            "An unofficial local utility with no affiliation with or endorsement by OpenAI.\n\nQuota features only read local Codex runtime events. They do not read account credentials or upload quota data or logs. A custom background is resized and copied to the local application data directory; it is never uploaded.\n\n“Follow local weather” is off by default. When you enable it, the app obtains your location through the operating system, rounds latitude and longitude to two decimal places, and sends that coarse location to Open-Meteo only to determine whether it is raining or snowing. The app includes no telemetry.\n\nWeather data: Open-Meteo (CC BY 4.0)\nhttps://open-meteo.com/"
        )
    }

    static func weatherLinkStatus(_ status: WeatherLinkStatus) -> String {
        switch status {
        case .disabled: return localized("天气联动：已关闭", "Weather link: Off")
        case .locating: return localized("天气联动：正在获取位置…", "Weather link: Locating…")
        case .checking: return localized("天气联动：正在查询…", "Weather link: Checking…")
        case .dry: return localized("天气联动：当前无降水", "Weather link: No precipitation")
        case .raining: return localized("天气联动：当前下雨", "Weather link: Raining")
        case .snowing: return localized("天气联动：当前下雪", "Weather link: Snowing")
        case .permissionDenied: return localized("天气联动：位置权限未开启", "Weather link: Location denied")
        case .unavailable: return localized("天气联动：暂时无法更新", "Weather link: Temporarily unavailable")
        }
    }

    static func themeAccessibilityName(_ theme: QuotaTheme) -> String {
        switch theme {
        case .forest: return localized("额度充足", "Quota available")
        case .autumn: return localized("额度偏低", "Quota running low")
        case .apocalypse: return localized("额度紧张", "Quota nearly depleted")
        case .wasteland: return localized("额度即将耗尽", "Quota almost exhausted")
        }
    }

    static func accessibilityLabel(title: String, remainingPercent: Int?, theme: String, isStashed: Bool, isExpanded: Bool) -> String {
        let percent = remainingPercent.map { localized("剩余 \($0)%", "\($0)% remaining") } ?? waitingForQuota
        let mode: String
        if isStashed {
            mode = localized("已收纳，悬停显示完整卡片", "Stashed. Hover to reveal the full card")
        } else {
            mode = isExpanded
                ? localized("单击收起，双击刷新", "Click to collapse. Double-click to refresh")
                : localized("单击展开，双击刷新", "Click to expand. Double-click to refresh")
        }
        return localized(
            "\(title)，\(percent)，\(theme)。\(mode)。",
            "\(title), \(percent), \(theme). \(mode)."
        )
    }

    static var accessibilityHelp: String {
        localized(
            "可拖动卡片；拖到屏幕左侧或右侧可收纳。右键打开菜单。",
            "Drag the card to move it. Drag to either screen edge to stash it. Right-click to open the menu."
        )
    }

    static var missingExecutable: String {
        localized("无法确定应用可执行文件位置", "Couldn’t locate the application executable")
    }
}
