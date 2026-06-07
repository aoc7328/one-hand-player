import SwiftUI
import UIKit

/// 指向某顆小圓：layer 0 = 第一層、layer 1 = 第二層（submenu）。
struct CircleRef: Equatable {
    let layer: Int
    let index: Int
}

/// 播放器手勢事件。由手勢層辨識後回報給 PlayerView 處理。
enum PlayerGestureEvent {
    case toggleControls                                  // 點空白處：顯示 / 隱藏（或收起第二層）
    case tapCircle(CircleRef)                            // 點某顆小圓
    case longPressCircle(CircleRef)                      // 按住某顆小圓（展開第二層）
    case circleDragBegan(CircleRef)
    case circleDragChanged(ref: CircleRef, translation: CGSize, viewSize: CGSize)
    case circleDragEnded(ref: CircleRef, translation: CGSize)
    case regionDoubleTap                                 // 半圓區雙擊：縮放
    case regionPanBegan
    case regionPanChanged(CGSize)                        // 半圓區拖曳：平移
    case regionPanEnded
}

/// 全螢幕手勢層。
///
/// 用 UIKit 手勢辨識器做精準命中判定（哪顆小圓 / 哪一層 / 是否在半圓區內），把
/// 所有觸控轉成語意化事件。視覺小圓由上層 SwiftUI 繪製且不吃觸控，命中完全以
/// 傳入的幾何為準，確保看到的位置 == 可操作的位置。
struct PlayerGestureView: UIViewRepresentable {

    /// 一顆可命中的小圓。
    struct HitCircle {
        let ref: CircleRef
        let center: CGPoint
        let radius: CGFloat
    }

    var circles: [HitCircle]
    var anchor: CGPoint
    var regionRadius: CGFloat
    var controlsVisible: Bool
    var isLocked: Bool
    var onEvent: (PlayerGestureEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let single = UITapGestureRecognizer(target: context.coordinator,
                                            action: #selector(Coordinator.handleSingleTap(_:)))
        let double = UITapGestureRecognizer(target: context.coordinator,
                                            action: #selector(Coordinator.handleDoubleTap(_:)))
        double.numberOfTapsRequired = 2
        single.require(toFail: double)

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1

        let longPress = UILongPressGestureRecognizer(target: context.coordinator,
                                                     action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.7

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

        private enum PanMode { case none, circle(CircleRef), region }
        private var panMode: PanMode = .none

        init(_ parent: PlayerGestureView) { self.parent = parent }

        /// 命中哪顆小圓（取最近且在半徑內者；第二層優先）。
        private func hitCircle(at p: CGPoint) -> CircleRef? {
            guard parent.controlsVisible else { return nil }
            var best: (ref: CircleRef, dist: CGFloat)?
            for c in parent.circles {
                let d = hypot(p.x - c.center.x, p.y - c.center.y)
                guard d <= c.radius else { continue }
                // 第二層優先，其次取最近
                if best == nil
                    || c.ref.layer > best!.ref.layer
                    || (c.ref.layer == best!.ref.layer && d < best!.dist) {
                    best = (c.ref, d)
                }
            }
            return best?.ref
        }

        private func inRegion(_ p: CGPoint) -> Bool {
            hypot(p.x - parent.anchor.x, p.y - parent.anchor.y) <= parent.regionRadius
        }

        @objc func handleSingleTap(_ g: UITapGestureRecognizer) {
            guard let view = g.view, !parent.isLocked else { return }
            let p = g.location(in: view)
            if let ref = hitCircle(at: p) {
                parent.onEvent(.tapCircle(ref))
            } else {
                parent.onEvent(.toggleControls)
            }
        }

        @objc func handleDoubleTap(_ g: UITapGestureRecognizer) {
            guard let view = g.view, !parent.isLocked else { return }
            let p = g.location(in: view)
            // 落在小圓上時不縮放（讓小圓自己的手勢處理）
            if hitCircle(at: p) == nil, inRegion(p) {
                parent.onEvent(.regionDoubleTap)
            }
        }

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            guard let view = g.view, !parent.isLocked, g.state == .began else { return }
            let p = g.location(in: view)
            if let ref = hitCircle(at: p) {
                parent.onEvent(.longPressCircle(ref))
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let view = g.view else { return }
            let raw = g.translation(in: view)
            let translation = CGSize(width: raw.x, height: raw.y)

            switch g.state {
            case .began:
                if parent.isLocked { panMode = .none; return }
                let start = g.location(in: view)
                if let ref = hitCircle(at: start) {
                    panMode = .circle(ref)
                    parent.onEvent(.circleDragBegan(ref))
                } else if inRegion(start) {
                    panMode = .region
                    parent.onEvent(.regionPanBegan)
                } else {
                    panMode = .none
                }

            case .changed:
                switch panMode {
                case .circle(let ref):
                    parent.onEvent(.circleDragChanged(ref: ref, translation: translation,
                                                      viewSize: view.bounds.size))
                case .region:
                    parent.onEvent(.regionPanChanged(translation))
                case .none:
                    break
                }

            case .ended, .cancelled, .failed:
                switch panMode {
                case .circle(let ref): parent.onEvent(.circleDragEnded(ref: ref, translation: translation))
                case .region:          parent.onEvent(.regionPanEnded)
                case .none:            break
                }
                panMode = .none

            default:
                break
            }
        }
    }
}
