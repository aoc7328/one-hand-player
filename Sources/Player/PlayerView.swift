import SwiftUI
import UIKit

/// 全螢幕播放畫面。
///
/// 互動核心（達文西調色盤式拇指面板）：
/// - 半圓上可自訂的功能小圓；點一下 = tap 功能，按住 2D 滑動 = drag 功能
///   （音量·亮度：上下音量、左右亮度；跳轉·速度：左右跳轉、上下速度）
/// - 半圓區雙擊 = 影片放大 / 縮回
/// - 半圓區空白拖曳（放大後）= 平移可視範圍
/// - 方向鎖 = 自動 / 鎖橫 / 鎖直循環
struct PlayerView: View {
    let item: MediaItem
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var controller = VLCPlayerController()

    @AppStorage("playerHandedness") private var handednessRaw = "right"
    @AppStorage(ArcConfig.storageKey) private var arcRaw = ArcConfig.defaultRaw

    @State private var controlsVisible = true
    @State private var isLocked = false
    @State private var hud: GestureHUD.Style?
    @State private var activeDragIndex: Int?

    // 影片縮放 / 平移
    @State private var zoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize = .zero

    // 方向
    @State private var orientationMode: ScreenOrientationMode = .auto

    // 量測畫面尺寸供手勢換算
    @State private var playerSize: CGSize = .zero

    // 拖曳起始值
    @State private var dragStartVolume = 100
    @State private var dragStartBrightness = 0.5
    @State private var dragStartTime: Double = 0
    @State private var dragStartRate: Float = 1
    @State private var seekTarget: Double = 0

    // 面板
    @State private var showMore = false
    @State private var showSpeedDialog = false
    @State private var showTracksDialog = false

    @State private var hideControlsTask: Task<Void, Never>?
    @State private var hideHUDTask: Task<Void, Never>?

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    private var functions: [PlayerFunction] { ArcConfig.decode(arcRaw) }
    private var isLeftHanded: Bool { handednessRaw == "left" }
    private var primaryIndex: Int? { functions.firstIndex(of: .playPause) }

    var body: some View {
        GeometryReader { geo in
            let geom = ArcGeometry(size: geo.size, isLeftHanded: isLeftHanded, count: functions.count)

            ZStack {
                Color.black.ignoresSafeArea()

                VLCVideoView(player: controller.player)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .ignoresSafeArea()
                    .clipped()

                // 手勢層（在視覺層之下，但視覺層的半圓不吃觸控，所以命中落在這裡）
                PlayerGestureView(
                    circles: hitCircles(geom),
                    anchor: geom.anchor,
                    regionRadius: geom.regionRadius,
                    controlsVisible: controlsVisible,
                    isLocked: isLocked,
                    onEvent: handle
                )
                .ignoresSafeArea()

                if controlsVisible && !isLocked {
                    Color.black.opacity(0.22).ignoresSafeArea().allowsHitTesting(false)
                    PlayerControlsView(
                        controller: controller,
                        title: item.title,
                        geometry: geom,
                        functions: functions,
                        orientationMode: orientationMode,
                        isZoomed: zoomScale > 1,
                        activeDragIndex: activeDragIndex,
                        onClose: close
                    )
                }

                if isLocked { lockedOverlay }

                if let hud {
                    GestureHUD(style: hud).transition(.opacity)
                }
            }
            .onAppear { playerSize = geo.size }
            .onChange(of: geo.size) { playerSize = $0 }
        }
        .statusBarHidden(true)
        .onAppear(perform: start)
        .onDisappear {
            controller.teardown()
            OrientationLock.apply(.auto)   // 離開時釋放方向鎖
        }
        .onChange(of: controller.didFinish) { if $0 { close() } }
        .sheet(isPresented: $showMore) {
            PlayerMoreSheet(controller: controller, orientationMode: $orientationMode)
        }
        .confirmationDialog("播放速度", isPresented: $showSpeedDialog, titleVisibility: .visible) {
            ForEach(speeds, id: \.self) { s in
                Button(String(format: "%.2g×", s)) { controller.setRate(Float(s)) }
            }
        }
        .confirmationDialog("字幕 / 音軌", isPresented: $showTracksDialog, titleVisibility: .visible) {
            ForEach(controller.subtitleTracks, id: \.index) { t in
                Button("字幕：\(t.name)") { controller.selectSubtitleTrack(t.index) }
            }
            ForEach(controller.audioTracks, id: \.index) { t in
                Button("音軌：\(t.name)") { controller.selectAudioTrack(t.index) }
            }
        }
    }

    // MARK: - 命中圓

    private func hitCircles(_ geom: ArcGeometry) -> [PlayerGestureView.HitCircle] {
        functions.indices.map { i in
            PlayerGestureView.HitCircle(
                index: i,
                center: geom.center(i),
                radius: i == primaryIndex ? 42 : 34
            )
        }
    }

    // MARK: - 生命週期

    private func start() {
        guard let url = library.resolvedURL(for: item) else { return }
        controller.load(url: url, itemID: item.id, resumeAt: item.positionSeconds) { id, pos, dur, force in
            library.updateProgress(for: id, position: pos, duration: dur, force: force)
        }
        dragStartVolume = controller.volume
        OrientationLock.apply(orientationMode)
        scheduleHideControls()
    }

    private func close() {
        controller.teardown()
        OrientationLock.apply(.auto)
        dismiss()
    }

    // MARK: - 事件分派

    private func handle(_ event: PlayerGestureEvent) {
        switch event {
        case .toggleControls:
            toggleControls()
        case .tapCircle(let i):
            guard functions.indices.contains(i) else { return }
            tapFunction(functions[i])
        case .circleDragBegan(let i):
            guard functions.indices.contains(i) else { return }
            activeDragIndex = i
            beginDrag(functions[i])
        case .circleDragChanged(let i, let t, let size):
            guard functions.indices.contains(i) else { return }
            updateDrag(functions[i], translation: t, viewSize: size)
        case .circleDragEnded(let i):
            if functions.indices.contains(i) { endDrag(functions[i]) }
            activeDragIndex = nil
            scheduleHideControls()
        case .regionDoubleTap:
            toggleZoom()
        case .regionPanBegan:
            panStart = panOffset
        case .regionPanChanged(let t):
            updatePan(t)
        case .regionPanEnded:
            break
        }
    }

    // MARK: - Tap 功能

    private func tapFunction(_ f: PlayerFunction) {
        switch f {
        case .playPause:
            controller.togglePlayPause(); Haptics.rigid()
        case .zoom:
            toggleZoom()
        case .orientation:
            cycleOrientation()
        case .lock:
            withAnimation { isLocked = true }; Haptics.selection()
        case .subtitleAudio:
            showTracksDialog = true
        case .speed:
            showSpeedDialog = true
        case .handedness:
            toggleHandedness()
        case .more:
            showMore = true
        case .volumeBrightness, .seekSpeed:
            break // 純拖曳型
        }
        if controlsVisible { scheduleHideControls() }
    }

    // MARK: - 2D 拖曳功能

    private func beginDrag(_ f: PlayerFunction) {
        hideControlsTask?.cancel()
        switch f {
        case .volumeBrightness:
            dragStartVolume = controller.volume
            dragStartBrightness = Double(UIScreen.main.brightness)
        case .seekSpeed:
            dragStartTime = controller.currentTime
            dragStartRate = controller.rate
            seekTarget = controller.currentTime
        default:
            break
        }
    }

    private func updateDrag(_ f: PlayerFunction, translation t: CGSize, viewSize: CGSize) {
        let w = max(viewSize.width, 1)
        let h = max(viewSize.height, 1)
        switch f {
        case .volumeBrightness:
            let vFrac = -t.height / h
            let newVol = min(max(dragStartVolume + Int(vFrac * 200), 0), 200)
            controller.setVolume(newVol)

            let hFrac = t.width / w
            let newBright = min(max(dragStartBrightness + Double(hFrac), 0), 1)
            UIScreen.main.brightness = CGFloat(newBright)

            showHUD(.dual(vIcon: "speaker.wave.2.fill", vText: "\(newVol)%",
                          hIcon: "sun.max.fill", hText: "\(Int(newBright * 100))%"),
                    autoDismiss: false)

        case .seekSpeed:
            let hFrac = t.width / w
            let target = min(max(dragStartTime + Double(hFrac) * 90, 0), controller.duration)
            seekTarget = target

            let vFrac = -t.height / h
            let newRate = min(max(dragStartRate + Float(vFrac) * 1.5, 0.25), 4.0)
            controller.setRate(newRate)

            let delta = target - dragStartTime
            let sign = delta >= 0 ? "+" : "−"
            showHUD(.dual(vIcon: "speedometer", vText: String(format: "%.2g×", Double(newRate)),
                          hIcon: "timeline.selection",
                          hText: "\(TimeFormatter.string(from: target)) (\(sign)\(TimeFormatter.string(from: abs(delta))))"),
                    autoDismiss: false)

        default:
            break
        }
    }

    private func endDrag(_ f: PlayerFunction) {
        if f == .seekSpeed {
            controller.seek(to: seekTarget); Haptics.selection()
        }
        dismissHUDSoon()
    }

    // MARK: - 縮放 / 平移

    private func toggleZoom() {
        let zoomIn = zoomScale <= 1
        withAnimation(.easeInOut(duration: 0.25)) {
            zoomScale = zoomIn ? 2 : 1
            if !zoomIn { panOffset = .zero }
        }
        Haptics.rigid()
        showHUD(.info(icon: zoomIn ? "plus.magnifyingglass" : "minus.magnifyingglass",
                      text: zoomIn ? "放大 2×" : "原始大小"),
                autoDismiss: true)
    }

    private func updatePan(_ t: CGSize) {
        guard zoomScale > 1 else { return }
        let maxX = playerSize.width * (zoomScale - 1) / 2
        let maxY = playerSize.height * (zoomScale - 1) / 2
        panOffset = CGSize(
            width: min(max(panStart.width + t.width, -maxX), maxX),
            height: min(max(panStart.height + t.height, -maxY), maxY)
        )
    }

    // MARK: - 方向 / 慣用手

    private func cycleOrientation() {
        orientationMode = orientationMode.next
        OrientationLock.apply(orientationMode)
        Haptics.selection()
        showHUD(.info(icon: orientationMode.icon, text: orientationMode.title), autoDismiss: true)
    }

    private func toggleHandedness() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            handednessRaw = isLeftHanded ? "right" : "left"
        }
        Haptics.rigid()
    }

    // MARK: - 控制顯隱 / HUD

    private func toggleControls() {
        withAnimation { controlsVisible.toggle() }
        if controlsVisible { scheduleHideControls() }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled { withAnimation { controlsVisible = false } }
        }
    }

    private func showHUD(_ style: GestureHUD.Style, autoDismiss: Bool) {
        withAnimation(.easeOut(duration: 0.12)) { hud = style }
        hideHUDTask?.cancel()
        if autoDismiss { dismissHUDSoon() }
    }

    private func dismissHUDSoon() {
        hideHUDTask?.cancel()
        hideHUDTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if !Task.isCancelled { withAnimation { hud = nil } }
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
