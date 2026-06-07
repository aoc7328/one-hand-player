import SwiftUI

/// 新增網路 / NAS 串流來源。
///
/// VLCKit 原生支援多種協定，直接把 URL 交給它即可：
/// - `http(s)://...`、`...m3u8`（HLS）
/// - `smb://使用者:密碼@主機/分享/影片.mkv`（NAS 區網直連）
/// - `ftp://`、`rtsp://`、WebDAV 的 http(s) 路徑等
struct AddNetworkSourceView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var urlString = ""
    @State private var title = ""

    private var isValid: Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              url.scheme != nil else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("網址") {
                    TextField("http://, https://, smb://, rtsp://…", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.callout)
                }
                Section("名稱（選填）") {
                    TextField("自訂顯示名稱", text: $title)
                }
                Section {
                    examplesView
                } header: {
                    Text("範例 / 提示")
                }
            }
            .navigationTitle("網路 / NAS 來源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入並播放") {
                        let item = library.addNetworkSource(urlString: urlString, title: title)
                        dismiss()
                        // 關閉 sheet 後再觸發播放，避免轉場衝突
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            library.nowPlaying = item
                        }
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var examplesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("NAS 區網直連（Synology/QNAP 開啟 SMB）", "smb://user:pass@192.168.1.10/video/movie.mkv")
            label("WebDAV / 直接 http", "https://nas.local:5006/movie.mp4")
            label("HLS 直播 / 串流", "https://example.com/stream.m3u8")
        }
        .font(.caption)
    }

    private func label(_ desc: String, _ example: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(desc).foregroundStyle(.secondary)
            Text(example).font(.caption.monospaced()).textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}
