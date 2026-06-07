import Foundation
import CoreGraphics

/// 單一物件相對其「預設位置」的個別調整：位移 (dx,dy) 與縮放 scale。
/// dx 以「右手」為基準；左手顯示時會自動水平鏡射。
struct LayoutAdjust: Codable, Equatable {
    var dx: Double = 0
    var dy: Double = 0
    var scale: Double = 1
}

/// 每物件調整的持久化（JSON 字串，存在 @AppStorage）。
/// key 規則：第一層功能 = "fn:<rawValue>"、第二層開關 = "tg:<rawValue>"。
enum LayoutStore {
    static func decode(_ raw: String) -> [String: LayoutAdjust] {
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: LayoutAdjust].self, from: data)
        else { return [:] }
        return dict
    }

    static func encode(_ dict: [String: LayoutAdjust]) -> String {
        guard let data = try? JSONEncoder().encode(dict),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }
}

/// 提供「第 i 顆小圓的最終中心 / 大小」，已套用半圓幾何 + 個別位移 / 縮放。
/// 視覺層 (PlayerControlsView / ArcPreviewView) 與手勢層 (命中判定) 共用同一份，
/// 確保看到的位置 == 可操作的位置。
struct ArcPlacement {
    let firstCenter: (Int) -> CGPoint
    let firstSize: (Int) -> CGFloat
    let secondCenter: (Int) -> CGPoint
    let secondSize: (Int) -> CGFloat
}
