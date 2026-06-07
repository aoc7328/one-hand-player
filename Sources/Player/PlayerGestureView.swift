import SwiftUI
import UIKit

/// 播放器手勢層。
///
/// 用 UIKit 手勢辨識器（而非 SwiftUI gesture）有兩個理由：
/// 1. 能精準拿到觸控座標，判斷螢幕左半 / 右半（亮度 vs 音量）。
/// 2. 多手勢（單擊、雙擊、拖曳、長按）共存與相依關係（單擊需等雙擊失敗）較好控制。
///
/// 全部以閉包回報，邏輯與畫面狀態仍留在 SwiftUI 的 `PlayerView`。
struct PlayerGestureView: UIViewRepresentable {

    enum DragAxis { case horizontal, vertical }
    enum ScreenSide { case left, right }

    /// 單擊（切換控制列顯示）。
    var onSingleTap: () -> Void
    /// 雙擊；帶上點擊落在左 / 中 / 右哪一區。
    var onDoubleTap: (_ side: ScreenSide?, _ isCenter: Bool) -> Void
    /// 拖曳變化。第一次移動決定 axis；vertical 時帶上左 / 右半邊。
    var onDragChanged: (_ axis: DragAxis, _ side: ScreenSide, _ translation: CGSize, _ viewSize: CGSize) -> Void
    var onDragEnded: () -> Void
    /// 長按開始 / 結束（用來做「按住加速」）。
    var onLongPressChanged: (_ active: Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        single.numberOfTapsRequired = 1

        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        double.numberOfTapsRequired = 2
        // 只有雙擊「失敗」時才認定為單擊，避免雙擊同時觸發單擊。
        single.require(toFail: double)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1

        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.45

        view.addGestureRecognizer(single)
        view.addGestureRecognizer(double)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(longPress)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var parent: PlayerGestureView
        private var currentAxis: DragAxis?
        private var dragSide: ScreenSide = .right

        init(_ parent: PlayerGestureView) { self.parent = parent }

        @objc func handleSingleTap(_ g: UITapGestureRecognizer) {
            parent.onSingleTap()
        }

        @objc func handleDoubleTap(_ g: UITapGestureRecognizer) {
            guard let view = g.view else { parent.onDoubleTap(nil, false); return }
            let x = g.location(in: view).x
            let w = view.bounds.width
            // 左 1/3、中 1/3、右 1/3
            if x < w / 3 {
                parent.onDoubleTap(.left, false)
            } else if x > w * 2 / 3 {
                parent.onDoubleTap(.right, false)
            } else {
                parent.onDoubleTap(nil, true)
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let view = g.view else { return }
            let translation = g.translation(in: view)

            switch g.state {
            case .began:
                currentAxis = nil
                let startX = g.location(in: view).x
                dragSide = startX < view.bounds.width / 2 ? .left : .right

            case .changed:
                // 第一次累積到門檻才鎖定方向，避免抖動誤判。
                if currentAxis == nil {
                    let absX = abs(translation.x)
                    let absY = abs(translation.y)
                    guard max(absX, absY) > 14 else { return }
                    currentAxis = absX > absY ? .horizontal : .vertical
                }
                guard let axis = currentAxis else { return }
                parent.onDragChanged(axis, dragSide,
                                     CGSize(width: translation.x, height: translation.y),
                                     view.bounds.size)

            case .ended, .cancelled, .failed:
                if currentAxis != nil { parent.onDragEnded() }
                currentAxis = nil

            default:
                break
            }
        }

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            switch g.state {
            case .began:
                parent.onLongPressChanged(true)
            case .ended, .cancelled, .failed:
                parent.onLongPressChanged(false)
            default:
                break
            }
        }
    }
}
