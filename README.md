# 單手播放器 One-Hand Player

一款 **單手就能操作** 的 iOS 影片播放器，主打：

- 🎬 **支援各種格式** — 以 [MobileVLCKit](https://code.videolan.org/videolan/VLCKit)（libVLC）為核心，MP4 / MKV / AVI / RMVB / FLV / TS / MOV / WMV… 幾乎都能播，內含/外掛字幕、多音軌。
- ⚡ **不卡頓** — 硬體加速解碼，網路快取調校。
- 👍 **單手操作** — 所有控制集中在螢幕下緣拇指熱區，配合全螢幕手勢，不用伸手去搆螢幕上方。
- 🗄️ **NAS 友善** — 可從 iOS「檔案」App 掛載的 NAS 讀檔，或直接輸入 `smb://`、`http(s)://`、WebDAV、`rtsp://` 等網址串流。

> 狀態：v1 功能完整、可編譯的原始碼。尚未簽章上架（見下方「如何裝到 iPhone」）。

---

## 單手操作

單擊畫面任意處可顯示 / 隱藏控制；核心操作集中在下面的拇指半圓面板。

### 拇指半圓控制面板（核心 · 達文西調色盤式）

主要操作集中在**以拇指根部為圓心的半圓**上，沿弧線排列**可自訂的功能小圓**（預設 6 個，可在「更多 → 自訂半圓功能」增刪、排序）：

| 互動 | 行為 |
|------|------|
| **點**功能小圓 | 觸發該功能（播放/暫停、縮放、方向鎖、更多…） |
| **按住**小圓 + 上下左右滑 | 2D 雙參數調整。例：**音量·亮度** → 上下音量、左右亮度；**跳轉·速度** → 左右跳轉、上下速度 |
| 半圓區**雙擊** | 影片放大 / 縮回（toggle） |
| 半圓區**空白拖曳**（放大後） | 平移可視範圍 |
| **方向鎖**小圓 | 循環 自動 → 鎖定橫向 → 鎖定直向（鎖定後不隨手機轉動改變） |

預設小圓：播放/暫停、音量·亮度、跳轉·速度、縮放、方向鎖、更多。

- **左右手互換**：「更多」面板一鍵把整個半圓翻到另一個下角，選擇會被記住。
- 頂部只放關閉、標題、細進度條（純資訊）。
- 全部小圓只負責「畫」，命中與拖曳由獨立手勢層依相同幾何判定，看到的位置 = 可操作的位置。

---

## 專案結構

```
Sources/
├─ App/            App 進入點、Info.plist
├─ Models/         MediaItem 資料模型
├─ Library/        媒體庫首頁、匯入、網路來源、列表列
├─ Player/         VLCKit 控制器、影像橋接、手勢層、控制列、HUD
└─ Utilities/      時間格式化、觸覺回饋
project.yml        XcodeGen 專案定義
Podfile            MobileVLCKit 依賴
.github/workflows/ 雲端 macOS 自動建置
```

設計上把 **播放核心（VLCPlayerController）** 與 **UI（SwiftUI 覆蓋層）** 分離，
之後若要換成 AVPlayer 或加新功能，UI 幾乎不用動。

---

## 如何裝到 iPhone（重要）

⚠️ **iOS App 一定要在 macOS + Xcode 上編譯、簽章**，這是 Apple 的限制，純手機無法繞過。
不過你不一定要「擁有」Mac，下面幾條路擇一：

### A. 有 Mac（最直接）
```bash
brew install xcodegen cocoapods
xcodegen generate            # 產生 .xcodeproj
pod install                  # 整合 MobileVLCKit
open OneHandPlayer.xcworkspace
```
在 Xcode 裡：
1. 選 target → Signing & Capabilities → 用你的 Apple ID 登入，勾「Automatically manage signing」。
2. 接上 iPhone，選你的裝置，按 ▶️ Run。
3. 第一次需到 iPhone「設定 → 一般 → VPN 與裝置管理」信任你的開發者憑證。

> 免費 Apple ID 簽章的 App 7 天到期，重連 Mac 重簽即可；付費開發者帳號（US$99/年）則 1 年。

### B. 沒有 Mac → 用雲端建置 + TestFlight
- 本 repo 已附 GitHub Actions（`.github/workflows/ios-build.yml`），每次 push 會在雲端 macOS 上驗證能否編譯。
- 要實際裝機，需 **Apple Developer Program（US$99/年）**，再用 **Xcode Cloud** 或 CI 打包後透過 **TestFlight** 安裝到手機。這條路設定較多，我可以再幫你接。

### C. 只是想先看程式碼 / 改需求
直接讀 `Sources/` 即可，不需任何環境。

---

## 連線 NAS 的兩種方式

1. **透過「檔案」App（推薦給多數人）**
   iOS「檔案」App → 右上「⋯」→「連接伺服器」→ 輸入 `smb://你的NAS位址`。
   之後在本 App 按 ＋ →「從『檔案』/ NAS 匯入」就能選到 NAS 上的影片。

2. **App 內直接輸入網址**
   按 ＋ →「新增網路 / NAS 網址」，例如：
   - `smb://user:pass@192.168.1.10/video/movie.mkv`
   - `https://nas.local:5006/movie.mp4`（WebDAV / http）
   - `https://example.com/stream.m3u8`（HLS）

---

## 後續可加

- 影片縮圖預覽、資料夾整理、播放清單
- 手勢靈敏度 / 配置自訂
- AVPlayer + VLCKit 混合（原生格式更省電）
- 投影 AirPlay、子母畫面 (PiP)
- 雲端打包 + TestFlight 自動發佈

有想優先做哪個，跟我說即可。
