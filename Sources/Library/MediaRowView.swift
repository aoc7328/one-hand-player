import SwiftUI

/// 媒體庫的單列：圖示 + 標題 + 來源 + 細進度條。
struct MediaRowView: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 64, height: 40)
                Image(systemName: item.kind == .network ? "network" : "film")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.kind == .network ? "網路 / NAS" : "本機檔案")
                    if item.durationSeconds > 0 {
                        Text("·")
                        Text(TimeFormatter.string(from: item.durationSeconds))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if item.isPartiallyWatched {
                    ProgressView(value: item.progressFraction)
                        .tint(.accentColor)
                        .scaleEffect(x: 1, y: 0.6, anchor: .center)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
