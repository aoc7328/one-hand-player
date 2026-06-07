import SwiftUI
import Foundation

/// 慣用手：決定弧形選單貼在左下角還是右下角。
enum Handedness: String {
    case left, right
}

/// 播放器覆蓋層控制元件。
///
/// 核心設計：主要按鈕沿著**以拇指根部為圓心的弧線**排列（拇指自然劃過的半圓），
/// 而不是傳統的底部一橫排。弧線可一鍵在**左 / 右下角**之間切換，左右手都好操作。
///
/// - 頂部：關閉 + 標題 + 細進度條（純資訊，跳轉主要靠手勢）
/// - 角落圓心：慣用手切換鈕（點一下換邊）
/// - 弧線上：鎖定、−10 秒、播放/暫停（大顆置中）、+10 秒、更多
struct PlayerControlsView: View {
    @ObservedObject var controller: VLCPlayerController
    let title: String

    @Binding var isLocked: Bool
    let onClose: () -> Void

    /// 慣用手持久化（預設右手 → 弧線在右下角）。
    @AppStorage("playerHandedness") private var handednessRaw = Handedness.right.rawValue
    private var isLeftHanded: Bool { handednessRaw == Handedness.left.rawValue }

    /// 拖曳進度條時的暫存值（放開才真正 seek）。
    @State private var scrubValue: Double = 0
    @State private var isScrubbing = false

    /// 弧線上的按鈕順序（圓心 → 上方）。
    private enum ArcAction: CaseIterable {
        case lock, back10, playPause, forward10, more
    }

    // 弧線幾何參數
    private let pivotInset: CGFloat = 46
    private let startDeg: Double = 14   // 接近水平（靠近拇指根）
    private let endDeg: Double = 90     // 垂直向上

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // 頂部資訊區
                VStack(spacing: 8) {
                    topBar
                    progressBar
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // 弧線導引（虛線，提示拇指劃過的路徑）
                arcGuide(in: geo.size)

                // 弧線上的功能按鈕
                ForEach(Array(ArcAction.allCases.enumerated()), id: \.offset) { index, action in
                    arcButton(action)
                        .position(buttonPosition(index: index,
                                                 count: ArcAction.allCases.count,
                                                 in: geo.size))
                }

                // 角落圓心：慣用手切換
                handednessPivot
                    .position(anchor(in: geo.size))
            }
        }
    }

    // MARK: - 頂部資訊

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
            if controller.isBuffering {
                ProgressView().tint(.white)
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

    // MARK: - 弧線按鈕

    @ViewBuilder
    private func arcButton(_ action: ArcAction) -> some View {
        switch action {
        case .lock:
            circleButton("lock.open.fill", size: 50) {
                withAnimation { isLocked = true }
                Haptics.selection()
            }
        case .back10:
            circleButton("gobackward.10", size: 50) {
                controller.skip(-10); Haptics.light()
            }
        case .playPause:
            circleButton(controller.isPlaying ? "pause.fill" : "play.fill",
                         size: 68, prominent: true) {
                controller.togglePlayPause(); Haptics.rigid()
            }
        case .forward10:
            circleButton("goforward.10", size: 50) {
                controller.skip(10); Haptics.light()
            }
        case .more:
            moreMenu
        }
    }

    private func circleButton(_ icon: String,
                              size: CGFloat,
                              prominent: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: prominent ? 30 : 22, weight: .semibold))
                .frame(width: size, height: size)
                .background {
                    Circle().fill(.ultraThinMaterial)
                    if prominent { Circle().fill(.white.opacity(0.16)) }
                }
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .foregroundStyle(.white)
                .contentShape(Circle())
        }
    }

    private var moreMenu: some View {
        Menu {
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                    Button {
                        controller.setRate(Float(r))
                    } label: {
                        Label(String(format: "%.2g×", r),
                              systemImage: controller.rate == Float(r) ? "checkmark" : "")
                    }
                }
            } label: {
                Label("播放速度（目前 \(String(format: "%.2g", Double(controller.rate)))×）",
                      systemImage: "speedometer")
            }

            if !controller.audioTracks.isEmpty {
                Menu {
                    ForEach(controller.audioTracks, id: \.index) { track in
                        Button {
                            controller.selectAudioTrack(track.index)
                        } label: {
                            Label(track.name,
                                  systemImage: controller.currentAudioTrack == track.index ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("音軌", systemImage: "waveform")
                }
            }

            if !controller.subtitleTracks.isEmpty {
                Menu {
                    ForEach(controller.subtitleTracks, id: \.index) { track in
                        Button {
                            controller.selectSubtitleTrack(track.index)
                        } label: {
                            Label(track.name,
                                  systemImage: controller.currentSubtitleTrack == track.index ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label("字幕", systemImage: "captions.bubble")
                }
            }

            Divider()

            Button {
                toggleHandedness()
            } label: {
                Label(isLeftHanded ? "切換成右手" : "切換成左手",
                      systemImage: "hand.point.up.left")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 50, height: 50)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .foregroundStyle(.white)
                .contentShape(Circle())
        }
    }

    // MARK: - 慣用手切換圓心

    private var handednessPivot: some View {
        Button {
            toggleHandedness()
        } label: {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.12)))
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .foregroundStyle(.white.opacity(0.85))
                // 左手時讓手掌圖示鏡像，視覺上更直覺
                .scaleEffect(x: isLeftHanded ? -1 : 1, y: 1)
        }
    }

    private func toggleHandedness() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            handednessRaw = isLeftHanded ? Handedness.right.rawValue : Handedness.left.rawValue
        }
        Haptics.rigid()
    }

    // MARK: - 弧線幾何

    /// 拇指根部圓心（角落）。
    private func anchor(in size: CGSize) -> CGPoint {
        CGPoint(x: isLeftHanded ? pivotInset : size.width - pivotInset,
                y: size.height - pivotInset)
    }

    /// 半徑：依畫面高度縮放並設上限，避免在直向時弧線太高搆不到。
    private func radius(in size: CGSize) -> CGFloat {
        min(max(size.height * 0.62, 150), 240)
    }

    /// 弧線上參數 t（0 圓心側 → 1 頂端）對應的座標。
    private func pointOnArc(_ t: Double, in size: CGSize) -> CGPoint {
        let a = anchor(in: size)
        let r = radius(in: size)
        let deg = startDeg + (endDeg - startDeg) * t
        let rad = deg * .pi / 180
        let dx = CGFloat(cos(rad)) * r * (isLeftHanded ? 1 : -1)
        let dy = -CGFloat(sin(rad)) * r
        return CGPoint(x: a.x + dx, y: a.y + dy)
    }

    private func buttonPosition(index: Int, count: Int, in size: CGSize) -> CGPoint {
        let t = count > 1 ? Double(index) / Double(count - 1) : 0
        return pointOnArc(t, in: size)
    }

    private func arcGuide(in size: CGSize) -> some View {
        Path { path in
            let steps = 32
            for i in 0...steps {
                let pt = pointOnArc(Double(i) / Double(steps), in: size)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
        }
        .stroke(.white.opacity(0.14),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
    }
}
