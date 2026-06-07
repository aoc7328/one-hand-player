import Foundation
import SwiftUI

/// App 的單一資料來源：管理媒體清單、匯入檔案、儲存播放進度。
///
/// 資料以 JSON 形式持久化到 Application Support；本機影片檔本身複製到
/// 沙盒的 Media/ 目錄，這樣即使原始來源（例如「檔案」App 暫存）消失也還能播。
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var items: [MediaItem] = []

    /// 由 LibraryView 觀察：被點開要播放的項目。
    @Published var nowPlaying: MediaItem?

    private let fileManager = FileManager.default

    /// 進度寫檔節流：上次實際寫入磁碟的時間。
    private var lastProgressSave = Date.distantPast

    private var supportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("OneHandPlayer", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var mediaDirectory: URL {
        let dir = supportDirectory.appendingPathComponent("Media", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var indexURL: URL {
        supportDirectory.appendingPathComponent("library.json")
    }

    init() {
        load()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([MediaItem].self, from: data) else {
            return
        }
        items = decoded.sorted { ($0.lastPlayed ?? $0.dateAdded) > ($1.lastPlayed ?? $1.dateAdded) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - 排序輔助

    /// 看過一半、可「繼續播放」的項目（最近在前）。
    var continueWatching: [MediaItem] {
        items.filter { $0.isPartiallyWatched }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
    }

    var allSortedByRecent: [MediaItem] {
        items.sorted { ($0.lastPlayed ?? $0.dateAdded) > ($1.lastPlayed ?? $1.dateAdded) }
    }

    // MARK: - 匯入本機檔案

    /// 從文件選擇器選到的 URL 匯入。會把檔案複製進沙盒，並建立安全範圍書籤。
    /// 回傳是否成功，讓 UI 可顯示錯誤。
    @discardableResult
    func importLocalFile(from pickedURL: URL) -> Bool {
        let needsScope = pickedURL.startAccessingSecurityScopedResource()
        defer { if needsScope { pickedURL.stopAccessingSecurityScopedResource() } }

        let filename = pickedURL.lastPathComponent
        let destination = uniqueDestination(for: filename)

        do {
            // 若已存在同名暫存就先清掉
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: pickedURL, to: destination)
        } catch {
            return false
        }

        let bookmark = try? destination.bookmarkData()
        let item = MediaItem(
            title: pickedURL.deletingPathExtension().lastPathComponent,
            kind: .localFile,
            location: destination.lastPathComponent, // 只存檔名，避免沙盒路徑改變失效
            bookmarkData: bookmark
        )
        insert(item)
        return true
    }

    /// 處理由其他 App / 「檔案」「用 OneHandPlayer 開啟」傳進來的 URL。
    func handleIncomingURL(_ url: URL) {
        if url.isFileURL {
            if importLocalFile(from: url) {
                nowPlaying = items.first // 匯入後排在最前，直接播
            }
        } else {
            let item = addNetworkSource(urlString: url.absoluteString, title: url.lastPathComponent)
            nowPlaying = item
        }
    }

    private func uniqueDestination(for filename: String) -> URL {
        var candidate = mediaDirectory.appendingPathComponent(filename)
        var counter = 1
        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        while fileManager.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base)-\(counter)" : "\(base)-\(counter).\(ext)"
            candidate = mediaDirectory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    // MARK: - 網路 / NAS 來源

    /// 新增一個網路 / NAS 來源（http/https/m3u8/webdav/smb...）。VLCKit 直接吃 URL。
    @discardableResult
    func addNetworkSource(urlString: String, title: String) -> MediaItem {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (URL(string: trimmed)?.lastPathComponent ?? trimmed)
            : title
        let item = MediaItem(title: displayTitle, kind: .network, location: trimmed)
        insert(item)
        return item
    }

    // MARK: - 解析播放網址

    /// 把 MediaItem 轉成可交給播放器的 URL。
    func resolvedURL(for item: MediaItem) -> URL? {
        switch item.kind {
        case .network:
            return URL(string: item.location)
        case .localFile:
            // 優先用書籤還原（最穩），失敗再用檔名拼回沙盒路徑。
            if let data = item.bookmarkData {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) {
                    return url
                }
            }
            return mediaDirectory.appendingPathComponent(item.location)
        }
    }

    // MARK: - 清單操作

    private func insert(_ item: MediaItem) {
        items.insert(item, at: 0)
        save()
    }

    func delete(_ item: MediaItem) {
        if item.kind == .localFile {
            let url = mediaDirectory.appendingPathComponent(item.location)
            try? fileManager.removeItem(at: url)
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: - 播放進度回寫

    /// 播放器定期 / 結束時呼叫，記住看到哪、總長度多少。
    /// 記憶體即時更新；磁碟寫入節流到最多每 5 秒一次（`force` 時立即寫，用於離開播放器）。
    func updateProgress(for itemID: UUID, position: Double, duration: Double, force: Bool = false) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].positionSeconds = position
        if duration > 0 { items[index].durationSeconds = duration }
        items[index].lastPlayed = Date()

        if force || Date().timeIntervalSince(lastProgressSave) > 5 {
            lastProgressSave = Date()
            save()
        }
    }
}
