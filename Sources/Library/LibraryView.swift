import SwiftUI
import UniformTypeIdentifiers

/// 首頁 / 媒體庫。
///
/// - 「繼續播放」橫向卡片（看到一半的）
/// - 全部媒體列表
/// - 右上 + ：從「檔案」匯入（含掛載在檔案 App 的 NAS）、或新增網路 / NAS 串流網址
struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore

    @State private var showFileImporter = false
    @State private var showNetworkSheet = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Group {
                if library.items.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("單手播放器")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("從「檔案」/ NAS 匯入", systemImage: "folder.badge.plus")
                        }
                        Button {
                            showNetworkSheet = true
                        } label: {
                            Label("新增網路 / NAS 網址", systemImage: "network")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        // 多選匯入；allowedContentTypes 放寬到 .data / .item 以支援 mkv/avi/rmvb 等冷門格式
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audiovisualContent, .movie, .video, .mpeg, .data, .item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showNetworkSheet) {
            AddNetworkSourceView()
        }
        .fullScreenCover(item: $library.nowPlaying) { item in
            PlayerView(item: item)
        }
        .alert("匯入失敗", isPresented: .constant(importError != nil)) {
            Button("好") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - 內容

    private var content: some View {
        List {
            if !library.continueWatching.isEmpty {
                Section("繼續播放") {
                    ForEach(library.continueWatching) { item in
                        MediaRowView(item: item)
                            .onTapGesture { library.nowPlaying = item }
                    }
                }
            }

            Section("全部") {
                ForEach(library.allSortedByRecent) { item in
                    MediaRowView(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { library.nowPlaying = item }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("還沒有任何影片")
                .font(.title3.weight(.semibold))
            Text("按右上角 ＋ 從「檔案」/ NAS 匯入，\n或貼上網路 / NAS 串流網址")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    showFileImporter = true
                } label: {
                    Label("匯入檔案", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Button {
                    showNetworkSheet = true
                } label: {
                    Label("網路 / NAS", systemImage: "network")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - 動作

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var failed = 0
            for url in urls where !library.importLocalFile(from: url) {
                failed += 1
            }
            if failed > 0 {
                importError = "有 \(failed) 個檔案無法匯入（可能是權限或格式問題）。"
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let sorted = library.allSortedByRecent
        for index in offsets {
            library.delete(sorted[index])
        }
    }
}
