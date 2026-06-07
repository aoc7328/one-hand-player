import Foundation

/// 來源類型：本機檔案，或網路 / NAS 串流。
enum MediaKind: String, Codable {
    case localFile      // 透過「檔案」App / iTunes 檔案共享匯入的本機檔案
    case network        // http(s)/m3u8/webdav/smb 等串流網址（含 NAS）
}

/// 一個可播放的媒體項目。
///
/// 同時用於「資料庫列表」與「傳給播放器」。本機檔案用安全範圍書籤
/// (security-scoped bookmark) 記住位置，避免下次開啟時權限失效。
struct MediaItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var kind: MediaKind

    /// network：完整 URL 字串。localFile：複製到沙盒後的相對路徑。
    var location: String

    /// localFile 專用：安全範圍書籤，用來在 App 重啟後仍能存取使用者選的檔案。
    var bookmarkData: Data?

    var dateAdded: Date
    var lastPlayed: Date?

    /// 已觀看秒數與總長度，用來顯示進度條與「繼續播放」。
    var positionSeconds: Double
    var durationSeconds: Double

    init(id: UUID = UUID(),
         title: String,
         kind: MediaKind,
         location: String,
         bookmarkData: Data? = nil,
         dateAdded: Date = Date(),
         lastPlayed: Date? = nil,
         positionSeconds: Double = 0,
         durationSeconds: Double = 0) {
        self.id = id
        self.title = title
        self.kind = kind
        self.location = location
        self.bookmarkData = bookmarkData
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.positionSeconds = positionSeconds
        self.durationSeconds = durationSeconds
    }

    /// 觀看進度 0...1，給列表上的細進度條用。
    var progressFraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(positionSeconds / durationSeconds, 0), 1)
    }

    /// 是否「看到一半」（用來決定要不要顯示「繼續播放」）。
    var isPartiallyWatched: Bool {
        progressFraction > 0.02 && progressFraction < 0.95
    }
}
