import Foundation
import CoreGraphics

/// 拇指半圓的幾何計算。
///
/// 圓心（拇指根部）落在側邊中線一帶：左手＝左緣、右手＝右緣，水平位置可由
/// `centerYFraction` 調整、與邊緣的距離可由 `edgeOffset` 調整（正值＝在螢幕外側），
/// 半徑 `baseRadius` 可縮放。半圓往螢幕中央打開。這些值由「編輯半圓」模式即時
/// 調整並持久化 —— 因此使用者能自己拖動位置、捏合縮放大小。
///
/// 角度以水平 x 軸（指向螢幕內）為 0°、向上為正、向下為負。index 0 在最上端。
struct ArcGeometry {
    let size: CGSize
    let isLeftHanded: Bool
    let count: Int

    /// 與近側邊的距離（正值＝圓心在螢幕外）。預設 ≈1cm。
    var edgeOffset: CGFloat = 55
    /// 圓心垂直位置（0 頂、1 底）。預設螢幕水平中線。
    var centerYFraction: CGFloat = 0.5
    /// 基準半徑。預設 ≈4cm。
    var baseRadius: CGFloat = 220
    /// 第二層往外擴的量。
    var extraRadius: CGFloat = 0

    var topDeg: Double = 60          // 上端（偏上、最順手），index 0
    var botDeg: Double = -40         // 下端（較不順手），最後一顆

    /// 拇指根部圓心。
    var anchor: CGPoint {
        CGPoint(x: isLeftHanded ? -edgeOffset : size.width + edgeOffset,
                y: size.height * centerYFraction)
    }

    /// 半徑；上限夾限以免超出畫面高度。
    var radius: CGFloat {
        min(baseRadius + extraRadius, size.height / 2 - 12)
    }

    var regionRadius: CGFloat { radius + 40 }

    /// 弧線上參數 t（0 上端 → 1 下端）對應座標。
    func point(t: Double) -> CGPoint {
        let a = anchor
        let r = radius
        let deg = topDeg - (topDeg - botDeg) * t
        let rad = deg * .pi / 180
        let dx = CGFloat(cos(rad)) * r * (isLeftHanded ? 1 : -1)
        let dy = -CGFloat(sin(rad)) * r
        return CGPoint(x: a.x + dx, y: a.y + dy)
    }

    /// 第 index 個小圓的圓心。
    func center(_ index: Int) -> CGPoint {
        let t = count > 1 ? Double(index) / Double(count - 1) : 0
        return point(t: t)
    }

    /// 是否落在半圓可操作區域內。
    func isInRegion(_ p: CGPoint) -> Bool {
        let a = anchor
        return hypot(p.x - a.x, p.y - a.y) <= regionRadius
    }
}
