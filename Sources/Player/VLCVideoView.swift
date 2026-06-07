import SwiftUI
import MobileVLCKit

/// 把 VLCMediaPlayer 的影像輸出 (`drawable`) 橋接成 SwiftUI 可用的 View。
///
/// 只負責提供一個 UIView 當畫布並設為 player 的 drawable，所有控制都在
/// 上層覆蓋層處理，保持單一職責。
struct VLCVideoView: UIViewRepresentable {
    let player: VLCMediaPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        player.drawable = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // drawable 已在 make 時綁定；尺寸變化由 Auto Layout / SwiftUI 處理。
        if player.drawable == nil {
            player.drawable = uiView
        }
    }
}
