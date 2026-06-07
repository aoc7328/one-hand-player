import SwiftUI

/// App 進入點。
///
/// 整個 App 採單一 `LibraryStore` 作為資料來源（最近播放、匯入的檔案、
/// 已儲存的 NAS / 網路來源），透過 `environmentObject` 注入給所有畫面。
@main
struct OneHandPlayerApp: App {
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .preferredColorScheme(.dark) // 播放器 App 預設深色比較不刺眼
                .onOpenURL { url in
                    // 從「檔案」App、AirDrop、其他 App「用 OneHandPlayer 開啟」時觸發
                    library.handleIncomingURL(url)
                }
        }
    }
}
