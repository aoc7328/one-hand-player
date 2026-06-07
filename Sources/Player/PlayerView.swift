import SwiftUI
import UIKit

/// 全螢幕播放畫面。
///
/// 互動框架（可擴充的多模式拇指面板）：
/// - 半圓平時隱藏，點畫面任一處開啟；4 秒無操作自動收起
/// - 第一層 5 顆小圓（上方好按放常用、下方放方向鎖）
/// - `tap` 功能：點一下；`drag2D`：按住上下左右調兩個參數
/// - `tapFlick`（播放/暫停）：點＝播放暫停；按住往右/左撥＝前進/後退一幀（看方向不看距離）
/// - `submenu`（快捷開關）：按住約 1 秒（或點一下）展開第二層；第二層往上滑＝開、往下＝關
/// - 半圓區雙擊＝縮放；放大後半圓空白拖曳＝平移
struct PlayerView: View {
    let item: MediaItem
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var controller = VLCPlayerController()

    @AppStorage("playerHandedness") private var handednessRaw = "right"
    @AppStorage(ArcConfig.storageKey) private var arcRaw = ArcConfig.defaultRaw

    // 半圓位置 / 大小（由「編輯半圓」模式調整、持久化）
    @AppStorage("arcEdgeOffset") private var arcEdgeOffset = 55.0
    @AppStorage("arcCenterY") private var arcCenterY = 0.5
    @AppStorage("arcRadius") private var arcRadius = 220.0
    // 每個物件的個別位移 / 縮放
    @AppStorage("arcObjectLayout") private var arcLayoutRaw = "{}"

    // 編輯模式
    @State private var editingArc = false
    @State private var dragStartEdge: Double?
    @State private var dragStartCenterY: Double?
    @State private var magStart: Double?
    @State private var editSelection: String?     // "arc" / "fn:<raw>" / nil
    @State private var startAdj = LayoutAdjust()
    @State private var dragActive = false
    @State private var dragTargetIsObject = false

    @State private var controlsVisible = false          // 平時隱藏
    @State private var isLocked = false
    @State private var hud: GestureHUD.Style?
    @State private var activeRef: CircleRef?

    // 第二層
    @State private var openSubmenu: PlayerFunction?
    @State private var loopEnabled = false
    @State private var muteEnabled = false

    // 影片縮放 / 平移
    @State private var zoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize = .zero

    @State private var orientationMode: ScreenOrientationMode = .auto
    @State private var playerSize: CGSize = .zero

    // 拖曳起始值
    @State private var dragStartVolume = 100
    @State private var dragStartBrightness = 0.5
    @State private var dragStartTime: Double = 0
    @State private var dragStartRate: Float = 1
    @State private var seekTarget: Double = 0
    @State private var flickStepX: CGFloat = 0           // 逐格撥動基準

    // 面板
    @State private var showMore = false
    @State private var showSpeedDialog = false
    @State private var showTracksDialog = false

    @State private var hideControlsTask: Task<Void, Never>?
    @State private var hideHUDTask: Task<Void, Never>?

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let submenuToggleList: [QuickToggle] = [.loop, .mute, .lock]

    private var functions: [PlayerFunction] { ArcConfig.decode(arcRaw) }
    private var isLeftHanded: Bool { handednessRaw == "left" }

    var body: some View {
        GeometryReader { geo in
            let geom = makeGeometry(size: geo.size, count: functions.count)
            let subGeom = makeGeometry(size: geo.size, count: submenuToggleList.count, extra: 86)
            let placement = ArcPlacement(
                firstCenter: { adjustedCenter(geom.center($0), firstID($0)) },
                firstSize: { 50 * CGFloat(adjust(firstID($0)).scale) },
                secondCenter: { adjustedCenter(subGeom.center($0), toggleID($0)) },
                secondSize: { 46 * CGFloat(adjust(toggleID($0)).scale) }
            )

            ZStack {
                Color.black.ignoresSafeArea()

                VLCVideoView(player: controller.player)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)
                    .ignoresSafeArea()
                    .clipped()

                if editingArc {
                    editOverlay(geom, placement)
                } else {
                    PlayerGestureView(
                        circles: hitCircles(placement),
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
                            placement: placement,
                            orientationMode: orientationMode,
                            isZoomed: zoomScale > 1,
                            activeRef: activeRef,
                            submenuToggles: openSubmenu != nil ? submenuToggleList : [],
                            toggleOn: toggleOn,
                            onClose: close,
                            onMore: { showMore = true }
                        )
                    }

                    if isLocked { lockedOverlay }
                }

                if let hud { GestureHUD(style: hud).transition(.opacity) }
            }
            .onAppear { playerSize = geo.size }
            .onChange(of: geo.size) { playerSize = $0 }
        }
        .statusBarHidden(true)
        .onAppear(perform: start)
        .onDisappear {
            controller.teardown()
            OrientationLock.apply(.auto)
        }
        .onChange(of: controller.didFinish) { finished in
            guard finished else { return }
            if loopEnabled { controller.replay() } else { close() }
        }
        .sheet(isPresented: $showMore) {
            PlayerMoreSheet(controller: controller, orientationMode: $orientationMode,
                            onEditArc: { withAnimation { editingArc = true } })
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

    // MARK: - 幾何（套用使用者調整的位置 / 大小）

    private func makeGeometry(size: CGSize, count: Int, extra: CGFloat = 0) -> ArcGeometry {
        ArcGeometry(size: size, isLeftHanded: isLeftHanded, count: count,
                    edgeOffset: CGFloat(arcEdgeOffset),
                    centerYFraction: CGFloat(arcCenterY),
                    baseRadius: CGFloat(arcRadius),
                    extraRadius: extra)
    }

    // MARK: - 每物件位移 / 縮放

    private var objectLayout: [String: LayoutAdjust] { LayoutStore.decode(arcLayoutRaw) }
    private func adjust(_ id: String) -> LayoutAdjust { objectLayout[id] ?? LayoutAdjust() }
    private func setAdjust(_ id: String, _ a: LayoutAdjust) {
        var d = objectLayout; d[id] = a; arcLayoutRaw = LayoutStore.encode(d)
    }
    private func firstID(_ i: Int) -> String { "fn:\(functions[i].rawValue)" }
    private func toggleID(_ i: Int) -> String { "tg:\(submenuToggleList[i].rawValue)" }

    /// 套用個別位移（dx 以右手為基準，左手鏡射）。
    private func adjustedCenter(_ base: CGPoint, _ id: String) -> CGPoint {
        let a = adjust(id)
        let sign: CGFloat = isLeftHanded ? -1 : 1
        return CGPoint(x: base.x + sign * CGFloat(a.dx), y: base.y + CGFloat(a.dy))
    }

    private func iconFor(_ f: PlayerFunction) -> String {
        switch f {
        case .playPause:   return controller.isPlaying ? "pause.fill" : "play.fill"
        case .orientation: return orientationMode.icon
        case .zoom:        return zoomScale > 1 ? "minus.magnifyingglass" : "plus.magnifyingglass"
        default:           return f.icon
        }
    }

    // MARK: - 編輯模式

    private var isObjectSelected: Bool { editSelection != nil && editSelection != "arc" }

    private var selectionName: String {
        guard let sel = editSelection, sel != "arc" else { return "整個半圓" }
        let raw = String(sel.dropFirst(3))
        return PlayerFunction(rawValue: raw)?.title ?? "物件"
    }

    @ViewBuilder
    private func editOverlay(_ geom: ArcGeometry, _ placement: ArcPlacement) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            ArcPreviewView(geometry: geom, functions: functions, placement: placement,
                           selectedId: editSelection, iconFor: iconFor)

            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(editDrag(placement))
                .simultaneousGesture(editMagnify)

            VStack {
                HStack(spacing: 12) {
                    Text("編輯").font(.headline)
                    Spacer()
                    Button("重設") { resetLayout() }
                        .buttonStyle(.bordered)
                    Button("完成") { withAnimation { editingArc = false }; editSelection = nil }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
                .tint(.white)

                Spacer()

                VStack(spacing: 4) {
                    Text("已選：\(selectionName)").font(.subheadline.weight(.medium))
                    Text(isObjectSelected
                         ? "拖動移動這顆・雙指縮放這顆大小"
                         : "點一顆小圓選取它・拖空白移動整個半圓・雙指縮放整體")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 10).padding(.horizontal, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 36)
            }
            .foregroundStyle(.white)
        }
        .transition(.opacity)
    }

    private func editDrag(_ placement: ArcPlacement) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !dragActive {
                    dragActive = true
                    if let i = firstHitIndex(v.startLocation, placement) {
                        editSelection = firstID(i)
                        dragTargetIsObject = true
                        startAdj = adjust(firstID(i))
                    } else {
                        editSelection = "arc"
                        dragTargetIsObject = false
                        dragStartEdge = arcEdgeOffset
                        dragStartCenterY = arcCenterY
                    }
                }
                if dragTargetIsObject, let id = editSelection {
                    let sign: Double = isLeftHanded ? -1 : 1
                    var a = startAdj
                    a.dx = startAdj.dx + sign * Double(v.translation.width)
                    a.dy = startAdj.dy + Double(v.translation.height)
                    setAdjust(id, a)
                } else if let e = dragStartEdge, let cy = dragStartCenterY {
                    let sign: Double = isLeftHanded ? -1 : 1
                    arcEdgeOffset = min(max(e + sign * Double(v.translation.width), -220), 400)
                    let h = max(Double(playerSize.height), 1)
                    arcCenterY = min(max(cy + Double(v.translation.height) / h, 0.12), 0.88)
                }
            }
            .onEnded { _ in
                dragActive = false; dragStartEdge = nil; dragStartCenterY = nil
            }
    }

    private var editMagnify: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if magStart == nil {
                    magStart = isObjectSelected ? adjust(editSelection!).scale : arcRadius
                }
                if isObjectSelected, let id = editSelection {
                    var a = adjust(id)
                    a.scale = min(max(magStart! * Double(scale), 0.4), 3.0)
                    setAdjust(id, a)
                } else {
                    arcRadius = min(max(magStart! * Double(scale), 90), 430)
                }
            }
            .onEnded { _ in magStart = nil }
    }

    private func firstHitIndex(_ p: CGPoint, _ placement: ArcPlacement) -> Int? {
        for i in functions.indices {
            let c = placement.firstCenter(i)
            let r = max(28, placement.firstSize(i) / 2 + 12)
            if hypot(p.x - c.x, p.y - c.y) <= r { return i }
        }
        return nil
    }

    private func resetLayout() {
        withAnimation {
            arcEdgeOffset = 55; arcCenterY = 0.5; arcRadius = 220
            arcLayoutRaw = "{}"
            editSelection = nil
        }
        Haptics.selection()
    }

    // MARK: - 命中圓

    private func hitCircles(_ placement: ArcPlacement) -> [PlayerGestureView.HitCircle] {
        var result = functions.indices.map { i in
            PlayerGestureView.HitCircle(ref: CircleRef(layer: 0, index: i),
                                        center: placement.firstCenter(i),
                                        radius: max(28, placement.firstSize(i) / 2 + 12))
        }
        if openSubmenu != nil {
            result += submenuToggleList.indices.map { i in
                PlayerGestureView.HitCircle(ref: CircleRef(layer: 1, index: i),
                                            center: placement.secondCenter(i),
                                            radius: max(26, placement.secondSize(i) / 2 + 10))
            }
        }
        return result
    }

    // MARK: - 生命週期

    private func start() {
        guard let url = library.resolvedURL(for: item) else { return }
        controller.load(url: url, itemID: item.id, resumeAt: item.positionSeconds) { id, pos, dur, force in
            library.updateProgress(for: id, position: pos, duration: dur, force: force)
        }
        dragStartVolume = controller.volume
        OrientationLock.apply(orientationMode)
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
            if openSubmenu != nil {
                withAnimation { openSubmenu = nil }
            } else {
                toggleControls()
            }

        case .tapCircle(let ref):
            if ref.layer == 0, functions.indices.contains(ref.index) {
                tapFunction(functions[ref.index])
            } else if ref.layer == 1, submenuToggleList.indices.contains(ref.index) {
                flipToggle(submenuToggleList[ref.index])
            }

        case .longPressCircle(let ref):
            if ref.layer == 0, functions.indices.contains(ref.index),
               functions[ref.index].interaction == .submenu {
                openSubmenuFor(functions[ref.index])
            }

        case .circleDragBegan(let ref):
            activeRef = ref
            hideControlsTask?.cancel()
            if ref.layer == 0, functions.indices.contains(ref.index) {
                switch functions[ref.index].interaction {
                case .drag2D:  beginDrag(functions[ref.index])
                case .tapFlick: flickStepX = 0
                default: break
                }
            }

        case .circleDragChanged(let ref, let t, let size):
            if ref.layer == 0, functions.indices.contains(ref.index) {
                switch functions[ref.index].interaction {
                case .drag2D:   updateDrag(functions[ref.index], translation: t, viewSize: size)
                case .tapFlick: handleFlick(t)
                default: break
                }
            }

        case .circleDragEnded(let ref, let t):
            if ref.layer == 0, functions.indices.contains(ref.index) {
                if case .drag2D = functions[ref.index].interaction { endDrag(functions[ref.index]) }
            } else if ref.layer == 1, submenuToggleList.indices.contains(ref.index) {
                let tg = submenuToggleList[ref.index]
                if t.height < -18 { setToggle(tg, true) }
                else if t.height > 18 { setToggle(tg, false) }
                else { flipToggle(tg) }
            }
            activeRef = nil
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
        case .playPause:     controller.togglePlayPause(); Haptics.rigid()
        case .zoom:          toggleZoom()
        case .orientation:   cycleOrientation()
        case .lock:          lock()
        case .toggles:       openSubmenuFor(.toggles)
        case .subtitleAudio: showTracksDialog = true
        case .speed:         showSpeedDialog = true
        case .handedness:    toggleHandedness()
        case .more:          showMore = true
        case .volumeBrightness, .seekSpeed: break
        }
        if controlsVisible { scheduleHideControls() }
    }

    // MARK: - 逐格撥動（tapFlick）

    private func handleFlick(_ t: CGSize) {
        let threshold: CGFloat = 26
        while t.width - flickStepX > threshold {
            controller.stepFrame(forward: true)
            flickStepX += threshold
            showHUD(.info(icon: "forward.frame.fill", text: "逐格 ▶"), autoDismiss: true)
        }
        while t.width - flickStepX < -threshold {
            controller.stepFrame(forward: false)
            flickStepX -= threshold
            showHUD(.info(icon: "backward.frame.fill", text: "◀ 逐格"), autoDismiss: true)
        }
    }

    // MARK: - 2D 拖曳功能（drag2D）

    private func beginDrag(_ f: PlayerFunction) {
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

    // MARK: - 第二層開關

    private func openSubmenuFor(_ f: PlayerFunction) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { openSubmenu = f }
        Haptics.selection()
        scheduleHideControls()
    }

    private func toggleOn(_ t: QuickToggle) -> Bool {
        switch t {
        case .loop: return loopEnabled
        case .mute: return muteEnabled
        case .lock: return isLocked
        }
    }

    private func setToggle(_ t: QuickToggle, _ on: Bool) {
        switch t {
        case .loop: loopEnabled = on
        case .mute: muteEnabled = on; controller.setMuted(on)
        case .lock: if on { lock() } else { isLocked = false }
        }
        Haptics.selection()
    }

    private func flipToggle(_ t: QuickToggle) { setToggle(t, !toggleOn(t)) }

    private func lock() {
        withAnimation { isLocked = true; openSubmenu = nil }
        Haptics.selection()
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
        if controlsVisible { scheduleHideControls() } else { openSubmenu = nil }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                withAnimation { controlsVisible = false; openSubmenu = nil }
            }
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
