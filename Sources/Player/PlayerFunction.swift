import Foundation

/// 可放到半圓小圓上的功能。
///
/// 每個功能有一種「互動模式」：
/// - `.tap`        點一下觸發
/// - `.drag2D`     按住 2D 連續調整（垂直、水平各一參數）
/// - `.tapFlick`   點一下＝主動作；按住後左右「撥動」＝離散步進（看方向不看距離）
/// - `.submenu`    按住約 1 秒（或點一下）展開第二層小圓
enum PlayerFunction: String, CaseIterable, Identifiable, Codable {
    case playPause          // tapFlick：點＝播放/暫停；撥右/左＝前進/後退一幀
    case volumeBrightness   // drag2D：上下音量、左右亮度
    case seekSpeed          // drag2D：左右跳轉、上下速度
    case zoom               // tap：放大 / 縮回
    case orientation        // tap：自動 → 鎖橫 → 鎖直
    case lock               // tap：鎖定畫面
    case toggles            // submenu：第二層快捷開關（循環 / 靜音 / 鎖定）
    case subtitleAudio      // tap：字幕 / 音軌
    case speed              // tap：速度選單
    case handedness         // tap：左右手互換
    case more               // tap：更多 / 自訂

    var id: String { rawValue }

    enum Interaction: Equatable {
        case tap
        case drag2D(hAxis: String, vAxis: String)
        case tapFlick(label: String)   // label 用於 HUD 提示
        case submenu
    }

    var interaction: Interaction {
        switch self {
        case .playPause:        return .tapFlick(label: "逐格")
        case .volumeBrightness: return .drag2D(hAxis: "亮度", vAxis: "音量")
        case .seekSpeed:        return .drag2D(hAxis: "跳轉", vAxis: "速度")
        case .toggles:          return .submenu
        default:                return .tap
        }
    }

    var title: String {
        switch self {
        case .playPause:        return "播放 / 暫停"
        case .volumeBrightness: return "音量 · 亮度"
        case .seekSpeed:        return "跳轉 · 速度"
        case .zoom:             return "縮放"
        case .orientation:      return "方向鎖"
        case .lock:             return "鎖定"
        case .toggles:          return "快捷開關"
        case .subtitleAudio:    return "字幕 · 音軌"
        case .speed:            return "速度"
        case .handedness:       return "左右手"
        case .more:             return "更多"
        }
    }

    /// 靜態圖示；會隨狀態變化的（播放/暫停、方向、鎖定、縮放）由 View 端動態覆寫。
    var icon: String {
        switch self {
        case .playPause:        return "playpause.fill"
        case .volumeBrightness: return "sun.max.fill"
        case .seekSpeed:        return "timeline.selection"
        case .zoom:             return "plus.magnifyingglass"
        case .orientation:      return "rotate.right.fill"
        case .lock:             return "lock.open.fill"
        case .toggles:          return "switch.2"
        case .subtitleAudio:    return "captions.bubble"
        case .speed:            return "speedometer"
        case .handedness:       return "hand.raised.fill"
        case .more:             return "ellipsis"
        }
    }
}

/// 第二層快捷開關項目。
enum QuickToggle: String, CaseIterable, Identifiable {
    case loop, mute, lock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loop: return "循環"
        case .mute: return "靜音"
        case .lock: return "鎖定"
        }
    }

    func icon(on: Bool) -> String {
        switch self {
        case .loop: return "repeat"
        case .mute: return on ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .lock: return on ? "lock.fill" : "lock.open.fill"
        }
    }
}

/// 半圓功能配置：以 @AppStorage 字串持久化（逗號分隔 rawValue）。
enum ArcConfig {
    static let storageKey = "arcFunctions"

    /// 預設 5 顆（依拇指順手度由上而下）：
    /// 播放暫停、音量·亮度、跳轉·速度、快捷開關（常用，上方），方向鎖（不常用，最下）。
    /// 「更多 / 自訂」移到頂列 ⋯，縮放可雙擊半圓，故不佔小圓。
    static let defaultFunctions: [PlayerFunction] =
        [.playPause, .volumeBrightness, .seekSpeed, .toggles, .orientation]

    static func decode(_ raw: String) -> [PlayerFunction] {
        let parsed = raw.split(separator: ",")
            .compactMap { PlayerFunction(rawValue: String($0)) }
        return parsed.isEmpty ? defaultFunctions : parsed
    }

    static func encode(_ functions: [PlayerFunction]) -> String {
        functions.map(\.rawValue).joined(separator: ",")
    }

    static var defaultRaw: String { encode(defaultFunctions) }
}

/// 螢幕方向模式。
enum ScreenOrientationMode: String, CaseIterable {
    case auto       // 跟隨裝置
    case landscape  // 強制並鎖定橫向
    case portrait   // 強制並鎖定直向

    var title: String {
        switch self {
        case .auto: return "自動"
        case .landscape: return "鎖定橫向"
        case .portrait: return "鎖定直向"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "rotate.right"
        case .landscape: return "rectangle.landscape.rotate"
        case .portrait: return "rectangle.portrait.rotate"
        }
    }

    var next: ScreenOrientationMode {
        switch self {
        case .auto: return .landscape
        case .landscape: return .portrait
        case .portrait: return .auto
        }
    }
}
