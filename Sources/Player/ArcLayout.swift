import Foundation
import CoreGraphics

/// 拇指半圓的幾何計算。
///
/// 以拇指根部（畫面下角）為圓心，沿弧線排列功能小圓；同一份幾何同時給
/// 「視覺層」(ArcControlsView) 與「手勢層」(PlayerGestureView) 使用，確保
/// 看到的小圓位置和實際可點擊 / 拖曳的判定完全一致。
///
/// 角度以水平 x 軸為 0°、垂直向上為 90°。拇指最好按的是「上半部」（靠垂直），
/// 所以 index 0 放在最頂端（90°，最舒適），index 越大越往下（靠水平、近拇指根，
/// 較不順手），常用功能擺前面、不常用的（方向鎖）擺最後。
struct ArcGeometry {
    let size: CGSize
    let isLeftHanded: Bool
    let count: Int

    var pivotInset: CGFloat = 46
    var startDeg: Double = 22       // 下端（靠水平、近拇指根，較不順手）
    var endDeg: Double = 90         // 上端（垂直，最順手）
    var extraRadius: CGFloat = 0    // 第二層用：往外擴一圈

    /// 拇指根部圓心。
    var anchor: CGPoint {
        CGPoint(x: isLeftHanded ? pivotInset : size.width - pivotInset,
                y: size.height - pivotInset)
    }

    /// 弧線半徑：依畫面高度縮放並設上限，避免直向時太高搆不到。
    var radius: CGFloat {
        min(max(size.height * 0.62, 150), 240) + extraRadius
    }

    /// 半圓「可操作區域」半徑（雙擊縮放 / 平移判定用）。
    var regionRadius: CGFloat {
        min(max(size.height * 0.62, 150), 240) + 52
    }

    /// 弧線上參數 t（0 頂端 → 1 下端）對應座標。
    func point(t: Double) -> CGPoint {
        let a = anchor
        let r = radius
        let deg = endDeg - (endDeg - startDeg) * t   // t=0 → 頂端(90°)
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
