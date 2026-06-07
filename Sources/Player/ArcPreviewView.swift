import SwiftUI

/// 半圓的純視覺呈現（弧線導引 + 功能小圓），不吃觸控。
/// 編輯模式用它即時預覽，並把目前選取的物件加上強調框。
struct ArcPreviewView: View {
    let geometry: ArcGeometry
    let functions: [PlayerFunction]
    let placement: ArcPlacement
    var selectedId: String? = nil
    var iconFor: (PlayerFunction) -> String = { $0.icon }

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
            .stroke(.white.opacity(0.16),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))

            // 圓心標記（可能在畫面外，夾到邊內）
            Circle().fill(.white.opacity(0.2)).frame(width: 12, height: 12)
                .position(clamp(geometry.anchor))

            ForEach(Array(functions.enumerated()), id: \.offset) { index, function in
                let size = placement.firstSize(index)
                let selected = selectedId == "fn:\(function.rawValue)"
                VStack(spacing: 3) {
                    Image(systemName: iconFor(function))
                        .font(.system(size: size * 0.4, weight: .semibold))
                    Text(function.title)
                        .font(.system(size: max(7, size * 0.16))).lineLimit(1).fixedSize()
                }
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(
                    Circle().strokeBorder(selected ? Color.accentColor : .white.opacity(0.25),
                                          lineWidth: selected ? 3 : 1)
                )
                .position(placement.firstCenter(index))
            }
        }
        .allowsHitTesting(false)
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 6), geometry.size.width - 6),
                y: min(max(p.y, 6), geometry.size.height - 6))
    }
}
