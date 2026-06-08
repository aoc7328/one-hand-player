# 在 Mac 上把 App 跑起來

> 你只要做下面幾步。第 3 步那行指令會自動把其餘東西（XcodeGen、CocoaPods、
> MobileVLCKit）裝好並開啟 Xcode。

## 步驟

### 1. 安裝 Xcode
從 **App Store** 搜尋「Xcode」安裝（檔案很大，約 15GB，要等一下）。
裝好後**打開一次**，同意授權條款再關掉。

### 2. 取得程式碼
打開「終端機」(Terminal)，貼上：

```bash
git clone https://github.com/aoc7328/one-hand-player.git
cd one-hand-player
git checkout claude/ios-video-player-drkm3
```

> 如果你之前已經 clone 過，改成：
> ```bash
> cd one-hand-player
> git fetch origin
> git checkout claude/ios-video-player-drkm3
> git pull
> ```

### 3. 一鍵準備並開啟
```bash
./bootstrap.sh
```
它會自動安裝需要的工具、產生專案、下載播放核心，最後幫你開啟 Xcode。
（第一次會花幾分鐘，請耐心等；中途可能要你輸入電腦密碼安裝 Homebrew。）

### 4. 執行
Xcode 開好後：
- 上方裝置選單選一個**模擬器**（例如 iPhone 15）→ 按左上角 **▶ Run**。
- 想裝到**自己的 iPhone**：見 `bootstrap.sh` 結尾或 README 的簽章說明。

---

## 遇到問題？
把 Xcode 或終端機裡的**紅色錯誤訊息整段複製**貼給 Claude，我來修。
（我在雲端、看不到你的畫面，所以要靠你貼錯誤訊息。）

常見狀況：
- **模擬器看影片/手勢卡卡** → 正常，模擬器是軟體模擬；真機才準。
- **要裝到手機卻說憑證問題** → 到 iPhone「設定 → 一般 → VPN 與裝置管理」信任憑證。
- **Bundle Identifier 衝突** → 在 Signing 設定把它改成 `com.你的名字.onehandplayer`。
