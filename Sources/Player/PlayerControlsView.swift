import SwiftUI

/// 播放器覆蓋層控制元件，**全部集中在螢幕下緣的拇指熱區**，這是「單手操作」的核心。
///
/// 上緣只放最小資訊（標題 + 關閉），主要互動（播放、跳轉、進度、速度、字幕、鎖定）
/// 都在底部一橫排，單手拿著手機時拇指能輕鬆覆蓋。
struct PlayerControlsView: View {
    @ObservedObject var controller: VLCPlayerController
    let title: String

    @Binding var isLocked: Bool
    let onClose: () -> Void

    /// 拖曳進度條時的暫存值（放開才真正 seek）。
    @State private var scrubValue: Double = 0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    // MARK: - 頂列（資訊最小化）

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

    // MARK: - 底部主控制區（拇指熱區）

    private var bottomBar: some View {
        VStack(spacing: 14) {
            progressBar

            HStack(spacing: 0) {
                iconButton("lock.open.fill") { withAnimation { isLocked = true } }
                Spacer()
                iconButton("gobackward.10") { controller.skip(-10); Haptics.light() }
                Spacer()
                // 中央大顆播放 / 暫停
                Button {
                    controller.togglePlayPause(); Haptics.rigid()
                } label: {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                        .frame(width: 72, height: 72)
                        .background(.white.opacity(0.15), in: Circle())
                }
                Spacer()
                iconButton("goforward.10") { controller.skip(10); Haptics.light() }
                Spacer()
                speedButton
            }

            // 次要功能列（字幕 / 音軌 / 音量），離底較遠所以放比較少用的
            HStack(spacing: 28) {
                if !controller.subtitleTracks.isEmpty || !controller.audioTracks.isEmpty {
                    tracksButton
                }
                Spacer()
                Label("\(controller.volume)%", systemImage: "speaker.wave.2.fill")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - 進度條

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

    // MARK: - 元件

    private func iconButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.title2)
                .frame(width: 56, height: 56)
                .foregroundStyle(.white)
        }
    }

    private var speedButton: some View {
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
            Text(String(format: "%.2g×", Double(controller.rate)))
                .font(.headline.monospacedDigit())
                .frame(width: 56, height: 56)
                .foregroundStyle(.white)
        }
    }

    private var tracksButton: some View {
        Menu {
            if !controller.audioTracks.isEmpty {
                Section("音軌") {
                    ForEach(controller.audioTracks, id: \.index) { track in
                        Button {
                            controller.selectAudioTrack(track.index)
                        } label: {
                            Label(track.name,
                                  systemImage: controller.currentAudioTrack == track.index ? "checkmark" : "")
                        }
                    }
                }
            }
            if !controller.subtitleTracks.isEmpty {
                Section("字幕") {
                    ForEach(controller.subtitleTracks, id: \.index) { track in
                        Button {
                            controller.selectSubtitleTrack(track.index)
                        } label: {
                            Label(track.name,
                                  systemImage: controller.currentSubtitleTrack == track.index ? "checkmark" : "")
                        }
                    }
                }
            }
        } label: {
            Label("字幕 / 音軌", systemImage: "captions.bubble")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
