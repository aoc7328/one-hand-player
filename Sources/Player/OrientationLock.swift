import UIKit

/// 套用 / 解除螢幕方向鎖定。
///
/// - 先設定 AppDelegate 的全域 mask（決定系統「允許」哪些方向）。
/// - 再主動觸發一次旋轉，讓畫面立刻轉到目標方向。
/// iOS 16+ 用 `requestGeometryUpdate`，iOS 15 用舊的 UIDevice 手法。
enum OrientationLock {

    static func apply(_ mode: ScreenOrientationMode) {
        let mask: UIInterfaceOrientationMask
        switch mode {
        case .auto:      mask = .all
        case .landscape: mask = .landscape
        case .portrait:  mask = .portrait
        }
        AppDelegate.orientationLock = mask

        if #available(iOS 16.0, *) {
            guard let scene = activeWindowScene else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            scene.keyWindow?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            let target: UIInterfaceOrientation
            switch mode {
            case .landscape: target = .landscapeRight
            case .portrait:  target = .portrait
            case .auto:      target = .unknown
            }
            // 私有但長年可用的旋轉手法（iOS 15 唯一實際做法）
            if target != .unknown {
                UIDevice.current.setValue(target.rawValue, forKey: "orientation")
            }
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    @available(iOS 16.0, *)
    private static var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ??
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
}
