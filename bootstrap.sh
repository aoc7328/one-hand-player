#!/usr/bin/env bash
#
# 一鍵把專案準備好並用 Xcode 開啟。
# 在 Mac 的「終端機」裡，進到專案資料夾後執行：  ./bootstrap.sh
#
# 前提：已從 App Store 安裝好 Xcode，並開啟過一次（接受授權）。
#
set -e

echo "==> 檢查 Xcode..."
if ! xcode-select -p >/dev/null 2>&1; then
  echo "找不到 Xcode 命令列工具，將安裝（會跳出視窗，請按安裝）..."
  xcode-select --install || true
  echo "請等命令列工具安裝完成後，再重新執行本腳本。"
  exit 1
fi

# 讓 Homebrew 在 Apple Silicon / Intel 都能找到
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

echo "==> 檢查 Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "安裝 Homebrew（會要求你輸入電腦密碼）..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
fi

echo "==> 安裝 xcodegen 與 cocoapods（第一次會比較久）..."
brew install xcodegen cocoapods

echo "==> 產生 Xcode 專案..."
xcodegen generate

echo "==> 安裝 MobileVLCKit（會下載數百 MB，請耐心等）..."
pod install --repo-update

echo ""
echo "✅ 完成！正在開啟 Xcode..."
open OneHandPlayer.xcworkspace

cat <<'NEXT'

接下來在 Xcode 裡：
  1. 最上方中間，點裝置選單，選一個模擬器（例如 iPhone 15）。
  2. 按左上角的 ▶（Run）。第一次編譯較久，等它跑完模擬器就會出現 App。
  3. 想裝到自己的 iPhone：
     - 左側點最上面的專案 → TARGETS 選 OneHandPlayer → 「Signing & Capabilities」
     - 勾「Automatically manage signing」，Team 選你的 Apple ID（沒有就 Add an Account 登入）
     - 若出現 Bundle Identifier 衝突，把它改成獨一無二的，例如 com.你的名字.onehandplayer
     - 用線接上 iPhone，裝置選單選你的手機，按 ▶
     - 第一次手機上要到「設定 → 一般 → VPN 與裝置管理」信任你的開發者憑證

有任何紅色錯誤訊息，整段複製給 Claude，我來修。
NEXT
