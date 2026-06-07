import Foundation
import MobileVLCKit
import SwiftUI
import Combine

/// 包裝 `VLCMediaPlayer` 的可觀察控制器。
///
/// 把 VLCKit 的指令式 / delegate 風格 API 轉成 SwiftUI 友善的 `@Published` 狀態，
/// 讓 `PlayerView` 的覆蓋層（控制列、HUD、手勢）可以直接綁定。
@MainActor
final class VLCPlayerController: NSObject, ObservableObject {

    // MARK: - 對外狀態
    @Published var isPlaying = false
    @Published var currentTime: Double = 0      // 秒
    @Published var duration: Double = 0          // 秒
    @Published var bufferingProgress: Double = 0 // 0...1（網路串流用）
    @Published var isBuffering = false
    @Published var rate: Float = 1.0
    @Published var volume: Int = 100             // 0...200（VLCKit 支援 >100 音量增益）

    /// 可選的音軌 / 字幕（index 與名稱對應）。
    @Published var audioTracks: [(index: Int32, name: String)] = []
    @Published var subtitleTracks: [(index: Int32, name: String)] = []
    @Published var currentAudioTrack: Int32 = -1
    @Published var currentSubtitleTrack: Int32 = -1

    /// 播放結束（給 UI 做「自動返回 / 下一部」）。
    @Published var didFinish = false

    let player = VLCMediaPlayer()

    /// 進度回寫用的識別與 callback。
    private var itemID: UUID?
    private var onProgress: ((UUID, Double, Double, Bool) -> Void)?
    private var resumeAt: Double = 0
    private var hasAppliedResume = false

    override init() {
        super.init()
        player.delegate = self
        // 預設音量 100
        player.audio?.volume = 100
    }

    // MARK: - 載入

    /// 載入並播放一個媒體。
    /// - Parameters:
    ///   - url: 本機 file:// 或 網路 http/smb/... URL
    ///   - resumeAt: 從第幾秒繼續（0 = 從頭）
    func load(url: URL, itemID: UUID, resumeAt: Double,
              onProgress: @escaping (UUID, Double, Double, Bool) -> Void) {
        self.itemID = itemID
        self.onProgress = onProgress
        self.resumeAt = resumeAt
        self.hasAppliedResume = false
        self.didFinish = false

        let media = VLCMedia(url: url)
        // 網路快取調大，串流 / NAS 比較不會卡頓（單位 ms）。
        media.addOptions([
            "network-caching": 1500,
            "file-caching": 600
        ])
        player.media = media
        player.play()
        isPlaying = true
    }

    // MARK: - 傳輸控制

    func togglePlayPause() {
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func play() {
        if !player.isPlaying { player.play() }
        isPlaying = true
    }

    func pause() {
        if player.isPlaying { player.pause() }
        isPlaying = false
    }

    /// 相對跳轉（秒）。正數快進、負數倒退。
    func skip(_ seconds: Int32) {
        if seconds >= 0 {
            player.jumpForward(seconds)
        } else {
            player.jumpBackward(-seconds)
        }
    }

    /// 絕對跳轉到某秒數（拖曳進度條用）。
    func seek(to seconds: Double) {
        guard duration > 0 else { return }
        let clamped = min(max(seconds, 0), duration)
        player.position = Float(clamped / duration)
        currentTime = clamped
    }

    /// 以 0...1 比例跳轉（手勢拖曳用，免除一次除法）。
    func seek(fraction: Float) {
        let clamped = min(max(fraction, 0), 1)
        player.position = clamped
    }

    // MARK: - 速度與音量

    func setRate(_ newRate: Float) {
        let clamped = min(max(newRate, 0.25), 4.0)
        player.rate = clamped
        rate = clamped
    }

    func setVolume(_ newVolume: Int) {
        let clamped = min(max(newVolume, 0), 200)
        player.audio?.volume = Int32(clamped)
        volume = clamped
    }

    // MARK: - 音軌 / 字幕

    private func refreshTracks() {
        if let indexes = player.audioTrackIndexes as? [NSNumber],
           let names = player.audioTrackNames as? [String] {
            audioTracks = zip(indexes, names).map { ($0.int32Value, $1) }
        }
        if let indexes = player.videoSubTitlesIndexes as? [NSNumber],
           let names = player.videoSubTitlesNames as? [String] {
            subtitleTracks = zip(indexes, names).map { ($0.int32Value, $1) }
        }
        currentAudioTrack = player.currentAudioTrackIndex
        currentSubtitleTrack = player.currentVideoSubTitleIndex
    }

    func selectAudioTrack(_ index: Int32) {
        player.currentAudioTrackIndex = index
        currentAudioTrack = index
    }

    func selectSubtitleTrack(_ index: Int32) {
        player.currentVideoSubTitleIndex = index
        currentSubtitleTrack = index
    }

    // MARK: - 結束

    /// 離開播放器前呼叫：回寫進度並停止。
    func teardown() {
        flushProgress(force: true)
        player.stop()
    }

    private func flushProgress(force: Bool = false) {
        guard let itemID else { return }
        onProgress?(itemID, currentTime, duration, force)
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlayerController: VLCMediaPlayerDelegate {

    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            let state = player.state
            switch state {
            case .buffering:
                isBuffering = true
            case .playing:
                isBuffering = false
                isPlaying = true
                if duration == 0 { duration = Double(player.media?.length.intValue ?? 0) / 1000.0 }
                refreshTracks()
                applyResumeIfNeeded()
            case .paused:
                isPlaying = false
            case .stopped, .ended:
                isPlaying = false
                flushProgress(force: true)
                if state == .ended { didFinish = true }
            case .error:
                isBuffering = false
            default:
                break
            }
        }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            currentTime = Double(player.time.intValue) / 1000.0
            if duration == 0, let length = player.media?.length.intValue, length > 0 {
                duration = Double(length) / 1000.0
            }
            applyResumeIfNeeded()
            // 每次時間更新就回寫，LibraryStore 內部會節流寫檔。
            flushProgress()
        }
    }

    /// 第一次有有效長度後，套用「繼續播放」起點（只做一次）。
    private func applyResumeIfNeeded() {
        guard !hasAppliedResume, resumeAt > 5, duration > 0 else { return }
        hasAppliedResume = true
        seek(to: resumeAt)
    }
}
