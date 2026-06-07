import Foundation
import CoreGraphics

/// 拇指半圓的幾何計算。
///
/// 圓心（拇指根部）落在**側邊中線**上：左手＝緊貼左邊緣、右手＝緊貼右邊緣，
/// 垂直位置在螢幕水平中線（height/2），圓心本身落在螢幕外側約 1cm。半圓往螢幕
/// 中央打開。半徑用「物理尺寸」（約 4cm）而非螢幕比例 —— 拇指是固定大小的。
///
/// 角度以水平 x 軸（指向螢幕內）為 0°、向上為正、向下為負。常用功能放上半部
/// （偏上、最順手），不常用的（方向鎖）放下半部。index 0 在最上端。
///
/// 換算：現代 iPhone 邏輯點約 55 pt/cm（不同機型 54–56，取概值，之後可微調）。
struct ArcGeometry {
    let size: CGSize
    let isLeftHanded: Bool
    let count: Int
    var extraRadius: CGFloat = 0

    /// ≈ 1 cm。圓心在螢幕側邊外的外推量。
    var sideOutset: CGFloat = 55
    /// ≈ 4 cm。基準半徑。
    var baseRadius: CGFloat = 220

    var topDeg: Double = 60         // 上端（偏上、最順手），index 0
    var botDeg: Double = -40        // 下端（過水平往下，較不順手），最後一顆

    /// 拇指根部圓心：側邊中線、螢幕外側約 1cm。
    var anchor: CGPoint {
        CGPoint(x: isLeftHanded ? -sideOutset : size.width + sideOutset,
                y: size.height / 2)
    }

    /// 半徑；夾限以免在矮畫面（橫向）時超出上下邊。
    var radius: CGFloat {
        min(baseRadius + extraRadius, size.height / 2 - 24)
    }

    /// 半圓「可操作區域」半徑（雙擊縮放 / 平移判定用）。
    var regionRadius: CGFloat { radius + 40 }

    /// 弧線上參數 t（0 上端 → 1 下端）對應座標。
    func point(t: Double) -> CGPoint {
        let a = anchor
        let r = radius
        let deg = topDeg - (topDeg - botDeg) * t   // t=0 → 上端
        let rad = deg * .pi / 180
        let dx = CGFloat(cos(rad)) * r * (isLeftHanded ? 1 : -1)  // 往螢幕內
        let dy = -CGFloat(sin(rad)) * r                          // 正角度=向上
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
