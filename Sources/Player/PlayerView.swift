import SwiftUI

/// 全螢幕播放畫面：影像層 + 手勢層 + 控制覆蓋層 + 手勢 HUD + 鎖定層。
///
/// 單手操作邏輯全部在這裡彙整：
/// - 單擊：顯示 / 隱藏控制列
/// - 雙擊左 / 右：快退 / 快進 10 秒；雙擊中央：播放 / 暫停
/// - 直向拖曳（左半）：亮度；（右半）：音量
/// - 橫向拖曳：精準跳轉（scrub）
/// - 長按：暫時 2× 加速，放開還原
/// - 鎖定鈕：避免口袋 / 單手誤觸
struct PlayerView: View {
    let item: MediaItem
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var controller = VLCPlayerController()

    @State private var controlsVisible = true
    @State private var isLocked = false
    @State private var hud: GestureHUD.Style?

    // 拖曳起始值（沒有 UIKit 的 .began 概念，第一次 changed 時捕捉）
    @State private var dragActive = false
    @State private var dragStartTime: Double = 0
    @State private var dragStartBrightness: Double = 0
    @State private var dragStartVolume: Int = 100
    @State private var seekTargetTime: Double = 0

    // 長按加速前的原速度
    @State private var rateBeforeBoost: Float = 1.0

    @State private var hideControlsTask: Task<Void, Never>?
    @State private var hideHUDTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCVideoView(player: controller.player)
                .ignoresSafeArea()

            // 手勢層鋪滿全螢幕
            PlayerGestureView(
                onSingleTap: handleSingleTap,
                onDoubleTap: handleDoubleTap,
                onDragChanged: handleDragChanged,
                onDragEnded: handleDragEnded,
                onLongPressChanged: handleLongPress
            )
            .ignoresSafeArea()

            // 控制覆蓋層
            if controlsVisible && !isLocked {
                Color.black.opacity(0.25).ignoresSafeArea()
                    .allowsHitTesting(false)
                PlayerControlsView(controller: controller,
                                   title: item.title,
                                   isLocked: $isLocked,
                                   onClose: close)
                    .transition(.opacity)
            }

            // 鎖定時的小解鎖鈕
            if isLocked {
                lockedOverlay
            }

            // 手勢 HUD
            if let hud {
                GestureHUD(style: hud)
                    .transition(.opacity)
            }
        }
        .statusBarHidden(true)
        .onAppear(perform: start)
        .onDisappear { controller.teardown() }
        .onChange(of: controller.didFinish) { finished in
            if finished { close() }
        }
    }

    // MARK: - 生命週期

    private func start() {
        guard let url = library.resolvedURL(for: item) else { return }
        // 網路 / NAS 來源要先取得安全範圍存取（本機書籤情況）
        controller.load(url: url,
                        itemID: item.id,
                        resumeAt: item.positionSeconds) { id, pos, dur, force in
            library.updateProgress(for: id, position: pos, duration: dur, force: force)
        }
        dragStartVolume = controller.volume
        scheduleHideControls()
    }

    private func close() {
        controller.teardown()
        dismiss()
    }

    // MARK: - 控制列自動隱藏

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                withAnimation { controlsVisible = false }
            }
        }
    }

    private func showHUD(_ style: GestureHUD.Style, autoDismiss: Bool) {
        withAnimation(.easeOut(duration: 0.12)) { hud = style }
        hideHUDTask?.cancel()
        if autoDismiss {
            hideHUDTask = Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                if !Task.isCancelled { withAnimation { hud = nil } }
            }
        }
    }

    // MARK: - 手勢處理

    private func handleSingleTap() {
        guard !isLocked else { return }
        withAnimation { controlsVisible.toggle() }
        if controlsVisible { scheduleHideControls() }
    }

    private func handleDoubleTap(side: PlayerGestureView.ScreenSide?, isCenter: Bool) {
        guard !isLocked else { return }
        if isCenter {
            controller.togglePlayPause()
            Haptics.rigid()
            return
        }
        guard let side else { return }
        let delta: Int32 = side == .left ? -10 : 10
        controller.skip(delta)
        Haptics.light()
        let target = min(max(controller.currentTime + Double(delta), 0), controller.duration)
        showHUD(.seek(target: target, total: controller.duration, delta: Double(delta)),
                autoDismiss: true)
    }

    private func handleDragChanged(axis: PlayerGestureView.DragAxis,
                                   side: PlayerGestureView.ScreenSide,
                                   translation: CGSize,
                                   viewSize: CGSize) {
        guard !isLocked else { return }

        if !dragActive {
            dragActive = true
            dragStartTime = controller.currentTime
            dragStartBrightness = Double(UIScreen.main.brightness)
            dragStartVolume = controller.volume
        }

        switch axis {
        case .horizontal:
            // 整個螢幕寬 ≈ 90 秒跳轉幅度
            let fraction = translation.width / max(viewSize.width, 1)
            let delta = Double(fraction) * 90.0
            let target = min(max(dragStartTime + delta, 0), controller.duration)
            seekTargetTime = target
            showHUD(.seek(target: target, total: controller.duration, delta: target - dragStartTime),
                    autoDismiss: false)

        case .vertical:
            // 往上 = 增加；整個螢幕高 = 滿格
            let fraction = -translation.height / max(viewSize.height, 1)
            if side == .left {
                let newValue = min(max(dragStartBrightness + Double(fraction), 0), 1)
                UIScreen.main.brightness = CGFloat(newValue)
                showHUD(.brightness(newValue), autoDismiss: false)
            } else {
                let newValue = min(max(dragStartVolume + Int(fraction * 200), 0), 200)
                controller.setVolume(newValue)
                showHUD(.volume(newValue), autoDismiss: false)
            }
        }
    }

    private func handleDragEnded() {
        guard !isLocked else { return }
        // 橫向拖曳放開時才真正 seek（拖曳中只更新 HUD，較省效能）
        if case .seek? = hud {
            controller.seek(to: seekTargetTime)
            Haptics.selection()
        }
        dragActive = false
        // 放開後短暫保留 HUD 再淡出
        hideHUDTask?.cancel()
        hideHUDTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled { withAnimation { hud = nil } }
        }
    }

    private func handleLongPress(active: Bool) {
        guard !isLocked else { return }
        if active {
            rateBeforeBoost = controller.rate
            controller.setRate(2.0)
            Haptics.rigid()
            showHUD(.speed(2.0), autoDismiss: false)
        } else {
            controller.setRate(rateBeforeBoost)
            withAnimation { hud = nil }
        }
    }

    // MARK: - 鎖定層

    private var lockedOverlay: some View {
        VStack {
            Spacer()
            Button {
                withAnimation { isLocked = false }
                controlsVisible = true
                scheduleHideControls()
                Haptics.selection()
            } label: {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 40)
        }
    }
}
