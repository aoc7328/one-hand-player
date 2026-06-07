import SwiftUI

/// 半圓的純視覺呈現（弧線導引 + 功能小圓），不吃觸控。
/// 編輯模式用它即時預覽位置 / 大小；正式播放時的小圓由 PlayerControlsView 繪製。
struct ArcPreviewView: View {
    let geometry: ArcGeometry
    let functions: [PlayerFunction]
    var dimLabels = false

    var body: some View {
        ZStack {
            // 導引虛線
            Path { path in
                let steps = 32
                for i in 0...steps {
                    let pt = geometry.point(t: Double(i) / Double(steps))
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
            }
            .stroke(.white.opacity(0.18),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))

            // 圓心標記（可能在畫面外）
            Circle().fill(.white.opacity(0.2)).frame(width: 12, height: 12)
                .position(clamp(geometry.anchor))

            ForEach(Array(functions.enumerated()), id: \.offset) { index, function in
                VStack(spacing: 3) {
                    Image(systemName: function.icon)
                        .font(.system(size: 20, weight: .semibold))
                    Text(function.title).font(.system(size: 8)).lineLimit(1).fixedSize()
                }
                .foregroundStyle(.white.opacity(dimLabels ? 0.85 : 1))
                .frame(width: 50, height: 50)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .position(geometry.center(index))
            }
        }
        .allowsHitTesting(false)
    }

    /// 把圓心標記夾到畫面邊內，至少看得到一點點。
    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 6), geometry.size.width - 6),
                y: min(max(p.y, 6), geometry.size.height - 6))
    }
}
