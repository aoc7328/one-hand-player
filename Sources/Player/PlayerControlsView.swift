import SwiftUI

/// 播放器覆蓋層「視覺」：頂列（關閉 / 標題 / 更多）、進度條、半圓功能小圓、第二層開關。
///
/// 小圓只負責「畫」，命中與拖曳由 `PlayerGestureView` 依相同幾何處理，因此整個
/// 半圓視覺都 `allowsHitTesting(false)`，只有頂列與進度條可互動。
struct PlayerControlsView: View {
    @ObservedObject var controller: VLCPlayerController
    let title: String
    let geometry: ArcGeometry
    let functions: [PlayerFunction]
    let orientationMode: ScreenOrientationMode
    let isZoomed: Bool
    let activeRef: CircleRef?

    // 第二層
    let submenuToggles: [QuickToggle]
    let submenuGeometry: ArcGeometry?
    let toggleOn: (QuickToggle) -> Bool

    let onClose: () -> Void
    let onMore: () -> Void

    @State private var scrubValue: Double = 0
    @State private var isScrubbing = false

    private let circleSize: CGFloat = 50

    var body: some View {
        ZStack(alignment: .topLeading) {
            arcVisuals
                .allowsHitTesting(false)

            VStack(spacing: 8) {
                topBar
                progressBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - 頂列

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer()
            if orientationMode != .auto {
                Image(systemName: orientationMode.icon)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            if controller.isBuffering {
                ProgressView().tint(.white)
            }
            Button(action: onMore) {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : controller.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(controller.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubValue = controller.currentTime
                    } else {
                        controller.seek(to: scrubValue)
                        isScrubbing = false
                    }
                }
            )
            .tint(.white)

            HStack {
                Text(TimeFormatter.string(from: isScrubbing ? scrubValue : controller.currentTime))
                Spacer()
                Text(TimeFormatter.string(from: controller.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - 半圓視覺

    private var arcVisuals: some View {
        ZStack {
            arcGuide

            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 12, height: 12)
                .position(geometry.anchor)

            // 第一層功能小圓
            ForEach(Array(functions.enumerated()), id: \.offset) { index, function in
                firstLayerCircle(function,
                                 isActive: activeRef == CircleRef(layer: 0, index: index))
                    .position(geometry.center(index))
            }

            // 第二層開關
            if let sg = submenuGeometry, !submenuToggles.isEmpty {
                ForEach(Array(submenuToggles.enumerated()), id: \.offset) { index, toggle in
                    secondLayerCircle(toggle,
                                      isActive: activeRef == CircleRef(layer: 1, index: index))
                        .position(sg.center(index))
                }
            }
        }
    }

    private func firstLayerCircle(_ function: PlayerFunction, isActive: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon(for: function))
                .font(.system(size: 20, weight: .semibold))
            Text(function.title)
                .font(.system(size: 8))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(.white)
        .frame(width: circleSize, height: circleSize)
        .background {
            Circle().fill(.ultraThinMaterial)
            if isActive { Circle().fill(.white.opacity(0.28)) }
        }
        .overlay(Circle().strokeBorder(.white.opacity(isActive ? 0.6 : 0.18),
                                       lineWidth: isActive ? 2 : 1))
        .scaleEffect(isActive ? 1.15 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
    }

    private func secondLayerCircle(_ toggle: QuickToggle, isActive: Bool) -> some View {
        let on = toggleOn(toggle)
        return VStack(spacing: 2) {
            Image(systemName: toggle.icon(on: on))
                .font(.system(size: 18, weight: .semibold))
            Text(toggle.title)
                .font(.system(size: 8))
        }
        .foregroundStyle(on ? Color.black : .white)
        .frame(width: 46, height: 46)
        .background {
            Circle().fill(on ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial))
            if isActive { Circle().fill(.white.opacity(0.25)) }
        }
        .overlay(Circle().strokeBorder(.white.opacity(isActive ? 0.7 : 0.3),
                                       lineWidth: isActive ? 2 : 1))
        .scaleEffect(isActive ? 1.15 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
    }

    /// 動態圖示（隨狀態變化的功能）。
    private func icon(for function: PlayerFunction) -> String {
        switch function {
        case .playPause:   return controller.isPlaying ? "pause.fill" : "play.fill"
        case .orientation: return orientationMode.icon
        case .zoom:        return isZoomed ? "minus.magnifyingglass" : "plus.magnifyingglass"
        default:           return function.icon
        }
    }

    private var arcGuide: some View {
        Path { path in
            let steps = 32
            for i in 0...steps {
                let pt = geometry.point(t: Double(i) / Double(steps))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
        }
        .stroke(.white.opacity(0.14),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
    }
}
