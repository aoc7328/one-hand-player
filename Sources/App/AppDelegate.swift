import UIKit

/// 提供「強制 / 鎖定螢幕方向」所需的 AppDelegate。
///
/// iOS 取得支援方向的唯一可靠來源就是 AppDelegate 的
/// `supportedInterfaceOrientationsFor`，所以用一個全域 mask 讓播放器能動態切換。
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 目前允許的方向；預設全部允許（自動旋轉）。
    static var orientationLock: UIInterfaceOrientationMask = .all

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
