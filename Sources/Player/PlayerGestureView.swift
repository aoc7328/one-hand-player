import SwiftUI
import UIKit

/// 播放器手勢事件。由手勢層辨識後回報給 PlayerView 處理。
enum PlayerGestureEvent {
    case toggleControls                              // 點空白處：顯示 / 隱藏控制
    case tapCircle(Int)                              // 點某個功能小圓
    case circleDragBegan(Int)
    case circleDragChanged(index: Int, translation: CGSize, viewSize: CGSize)
    case circleDragEnded(Int)
    case regionDoubleTap                             // 半圓區雙擊：縮放
    case regionPanBegan
    case regionPanChanged(CGSize)                    // 半圓區拖曳：平移可視範圍
    case regionPanEnded
}

/// 全螢幕手勢層。
///
/// 用 UIKit 手勢辨識器做精準命中判定（哪顆小圓 / 是否在半圓區內），把所有
/// 觸控轉成語意化事件。視覺上的小圓由上層 SwiftUI 繪製且不吃觸控，命中完全
/// 以這裡傳入的幾何為準，確保看到的位置 == 可操作的位置。
struct PlayerGestureView: UIViewRepresentable {

    /// 一顆可命中的小圓：索引、圓心、命中半徑。
    struct HitCircle {
        let index: Int
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

        view.addGestureRecognizer(single)
        view.addGestureRecognizer(double)
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var parent: PlayerGestureView

        private enum PanMode { case none, circle(Int), region }
        private var panMode: PanMode = .none

        init(_ parent: PlayerGestureView) { self.parent = parent }

        /// 命中哪顆小圓（取最近且在半徑內者）。
        private func hitCircle(at p: CGPoint) -> Int? {
            guard parent.controlsVisible else { return nil }
            var best: (index: Int, dist: CGFloat)?
            for c in parent.circles {
                let d = hypot(p.x - c.center.x, p.y - c.center.y)
                if d <= c.radius, best == nil || d < best!.dist {
                    best = (c.index, d)
                }
            }
            return best?.index
        }

        private func inRegion(_ p: CGPoint) -> Bool {
            hypot(p.x - parent.anchor.x, p.y - parent.anchor.y) <= parent.regionRadius
        }

        @objc func handleSingleTap(_ g: UITapGestureRecognizer) {
            guard let view = g.view, !parent.isLocked else { return }
            let p = g.location(in: view)
            if let idx = hitCircle(at: p) {
                parent.onEvent(.tapCircle(idx))
            } else {
                parent.onEvent(.toggleControls)
            }
        }

        @objc func handleDoubleTap(_ g: UITapGestureRecognizer) {
            guard let view = g.view, !parent.isLocked else { return }
            let p = g.location(in: view)
            if inRegion(p) {
                parent.onEvent(.regionDoubleTap)
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let view = g.view else { return }
            let translation = g.translation(in: view)

            switch g.state {
            case .began:
                if parent.isLocked { panMode = .none; return }
                let start = g.location(in: view)
                if let idx = hitCircle(at: start) {
                    panMode = .circle(idx)
                    parent.onEvent(.circleDragBegan(idx))
                } else if inRegion(start) {
                    panMode = .region
                    parent.onEvent(.regionPanBegan)
                } else {
                    panMode = .none
                }

            case .changed:
                switch panMode {
                case .circle(let idx):
                    parent.onEvent(.circleDragChanged(index: idx,
                                                      translation: CGSize(width: translation.x,
                                                                          height: translation.y),
                                                      viewSize: view.bounds.size))
                case .region:
                    parent.onEvent(.regionPanChanged(CGSize(width: translation.x,
                                                            height: translation.y)))
                case .none:
                    break
                }

            case .ended, .cancelled, .failed:
                switch panMode {
                case .circle(let idx): parent.onEvent(.circleDragEnded(idx))
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
