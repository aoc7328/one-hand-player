import SwiftUI

/// 手勢操作時，畫面中央短暫浮現的提示（亮度 / 音量 / 跳轉 / 加速）。
/// 單手操作看不到手指落點，這個即時回饋很關鍵。
struct GestureHUD: View {
    enum Style {
        case brightness(Double)        // 0...1
        case volume(Int)               // 0...200
        case seek(target: Double, total: Double, delta: Double) // 秒
        case speed(Float)
    }

    let style: Style

    var body: some View {
        Group {
            switch style {
            case .brightness(let value):
                bar(icon: value > 0.5 ? "sun.max.fill" : "sun.min.fill",
                    fraction: value,
                    label: "\(Int(value * 100))%")
            case .volume(let value):
                bar(icon: value == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    fraction: Double(value) / 200.0,
                    label: "\(value)%")
            case .seek(let target, let total, let delta):
                seekView(target: target, total: total, delta: delta)
            case .speed(let rate):
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill")
                    Text(String(format: "%.1f×", Double(rate)))
                        .font(.headline.monospacedDigit())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .shadow(radius: 8)
    }

    private func bar(icon: String, fraction: Double, label: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26))
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white)
                        .frame(height: geo.size.height * fraction)
                }
            }
            .frame(width: 6, height: 120)
            Text(label)
                .font(.caption.monospacedDigit())
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func seekView(target: Double, total: Double, delta: Double) -> some View {
        VStack(spacing: 6) {
            Text("\(TimeFormatter.string(from: target)) / \(TimeFormatter.string(from: total))")
                .font(.title3.monospacedDigit().bold())
            Text(String(format: "%@%@s", delta >= 0 ? "+" : "−", TimeFormatter.string(from: abs(delta))))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(delta >= 0 ? .green : .orange)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
