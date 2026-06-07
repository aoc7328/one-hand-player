import SwiftUI

/// 「更多」面板：方向鎖、慣用手、速度、字幕 / 音軌，以及進入「自訂半圓功能」。
struct PlayerMoreSheet: View {
    @ObservedObject var controller: VLCPlayerController
    @Binding var orientationMode: ScreenOrientationMode
    var onEditArc: () -> Void = {}

    @AppStorage("playerHandedness") private var handednessRaw = "right"
    @AppStorage(ArcConfig.storageKey) private var arcRaw = ArcConfig.defaultRaw

    @Environment(\.dismiss) private var dismiss

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationStack {
            Form {
                Section("螢幕方向") {
                    Picker("方向", selection: $orientationMode) {
                        ForEach(ScreenOrientationMode.allCases, id: \.self) { mode in
                            Label(mode.title, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .onChange(of: orientationMode) { OrientationLock.apply($0) }
                }

                Section("慣用手（半圓位置）") {
                    Picker("慣用手", selection: $handednessRaw) {
                        Text("右手").tag("right")
                        Text("左手").tag("left")
                    }
                    .pickerStyle(.segmented)
                }

                Section("播放速度") {
                    Picker("速度", selection: Binding(
                        get: { Double(controller.rate) },
                        set: { controller.setRate(Float($0)) }
                    )) {
                        ForEach(speeds, id: \.self) { s in
                            Text(String(format: "%.2g×", s)).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !controller.audioTracks.isEmpty {
                    Section("音軌") {
                        ForEach(controller.audioTracks, id: \.index) { track in
                            row(track.name, selected: controller.currentAudioTrack == track.index) {
                                controller.selectAudioTrack(track.index)
                            }
                        }
                    }
                }

                if !controller.subtitleTracks.isEmpty {
                    Section("字幕") {
                        ForEach(controller.subtitleTracks, id: \.index) { track in
                            row(track.name, selected: controller.currentSubtitleTrack == track.index) {
                                controller.selectSubtitleTrack(track.index)
                            }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        ArcCustomizeView(arcRaw: $arcRaw)
                    } label: {
                        Label("自訂半圓功能", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        dismiss()
                        onEditArc()
                    } label: {
                        Label("編輯半圓位置 / 大小", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    }
                } footer: {
                    Text("自訂功能：選擇半圓上的功能與順序（建議 5 個以上）。\n編輯位置 / 大小：單指拖動移動、雙指縮放，自己調到最順手。")
                }
            }
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
        }
    }
}

/// 自訂半圓功能：啟用哪些、順序。
struct ArcCustomizeView: View {
    @Binding var arcRaw: String
    @State private var functions: [PlayerFunction] = []

    private var available: [PlayerFunction] {
        PlayerFunction.allCases.filter { !functions.contains($0) }
    }

    var body: some View {
        List {
            Section {
                ForEach(functions) { fn in
                    Label(fn.title, systemImage: fn.icon)
                }
                .onMove { functions.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { functions.remove(atOffsets: $0) }
            } header: {
                Text("已啟用（拖曳排序、左滑刪除）")
            } footer: {
                if functions.count < 5 {
                    Text("目前少於 5 個，建議再加入一些。")
                        .foregroundStyle(.orange)
                }
            }

            if !available.isEmpty {
                Section("可加入") {
                    ForEach(available) { fn in
                        Button {
                            functions.append(fn)
                        } label: {
                            Label(fn.title, systemImage: "plus.circle")
                        }
                    }
                }
            }
        }
        .navigationTitle("自訂半圓功能")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onAppear { functions = ArcConfig.decode(arcRaw) }
        .onChange(of: functions) { arcRaw = ArcConfig.encode($0) }
    }
}
