import Foundation

/// 可放到半圓小圓上的功能。
///
/// 每個功能不是「點一下」型（tap）就是「按住 2D 滑動」型（drag2D）。
/// drag2D 把垂直、水平兩個方向各對應一個參數（達文西調色盤式）。
enum PlayerFunction: String, CaseIterable, Identifiable, Codable {
    case playPause          // 點一下：播放 / 暫停
    case volumeBrightness   // 按住：上下音量、左右亮度
    case seekSpeed          // 按住：左右跳轉、上下速度
    case zoom               // 點一下：放大 / 縮回（半圓區雙擊也可）
    case orientation        // 點一下：自動 → 鎖橫 → 鎖直 循環
    case lock               // 點一下：鎖定畫面避免誤觸
    case subtitleAudio      // 點一下：字幕 / 音軌選單
    case speed              // 點一下：播放速度選單
    case handedness         // 點一下：左右手互換
    case more               // 點一下：更多 / 自訂

    var id: String { rawValue }

    enum Interaction: Equatable {
        case tap
        /// 按住 2D 滑動。hAxis = 水平方向參數名、vAxis = 垂直方向參數名。
        case drag2D(hAxis: String, vAxis: String)
    }

    var interaction: Interaction {
        switch self {
        case .volumeBrightness: return .drag2D(hAxis: "亮度", vAxis: "音量")
        case .seekSpeed:        return .drag2D(hAxis: "跳轉", vAxis: "速度")
        default:                return .tap
        }
    }

    var isDrag: Bool {
        if case .drag2D = interaction { return true }
        return false
    }

    var title: String {
        switch self {
        case .playPause:        return "播放 / 暫停"
        case .volumeBrightness: return "音量 · 亮度"
        case .seekSpeed:        return "跳轉 · 速度"
        case .zoom:             return "縮放"
        case .orientation:      return "方向鎖"
        case .lock:             return "鎖定"
        case .subtitleAudio:    return "字幕 · 音軌"
        case .speed:            return "速度"
        case .handedness:       return "左右手"
        case .more:             return "更多"
        }
    }

    /// 靜態圖示；會隨狀態變化的（播放/暫停、方向、鎖定）由 View 端動態覆寫。
    var icon: String {
        switch self {
        case .playPause:        return "playpause.fill"
        case .volumeBrightness: return "sun.max.fill"
        case .seekSpeed:        return "timeline.selection"
        case .zoom:             return "plus.magnifyingglass"
        case .orientation:      return "rotate.right.fill"
        case .lock:             return "lock.open.fill"
        case .subtitleAudio:    return "captions.bubble"
        case .speed:            return "speedometer"
        case .handedness:       return "hand.raised.fill"
        case .more:             return "ellipsis"
        }
    }
}

/// 半圓功能配置：以 @AppStorage 字串持久化（逗號分隔 rawValue）。
enum ArcConfig {
    static let storageKey = "arcFunctions"

    /// 預設 6 顆（≥5）：播放暫停、音量亮度、跳轉速度、縮放、方向鎖、更多。
    static let defaultFunctions: [PlayerFunction] =
        [.playPause, .volumeBrightness, .seekSpeed, .zoom, .orientation, .more]

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
