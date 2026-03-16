# Claude Code Rate Limit Statusline ⚡

A lightweight, zero-cost, and 100% accurate rate limit statusline for **Claude Code** (Pro / Max tiers).
專為 Claude Code 設計的速率限制狀態列整合方案，精準顯示 Pro / Max 方案的 5 小時與 7 天額度。

## 💡 為什麼需要這個專案？ (Why?)

目前 Claude Code 官方的 `/statusline` API 並未提供具體的 Rate Limit 數據。如果寫腳本頻繁去戳官方的 Usage API，會極易觸發 `429 Too Many Requests` 封鎖。

**本專案的解法：**
透過在本地端建立一個極輕量的 Node.js 反向代理（Reverse Proxy），攔截並解析 Anthropic 官方 API 在正常對話中回傳的 `anthropic-ratelimit-unified-*` Headers，並轉化為原生 Statusline 可讀的格式。

## ✨ 特色 (Features)

* **🚫 無痛繞過 429 封鎖**：不發送任何額外查詢請求，完全依賴正常對話的攔截。
* **🎯 100% 官方精確數據**：直接讀取伺服器端 Unified Rate Limit，非本地端推算。
* **🌈 視覺化狀態列**：動態顏色顯示 5h 與 7d 剩餘額度百分比與重置時間（超過 50% 轉黃、80% 亮紅燈）。
* **👻 無痕背景執行**：所有的輸出導向 `/dev/null`，不佔用硬碟產生 Log 檔。
* **🐧 雙平台支援**：自動相容 macOS 與 Ubuntu/Linux 環境。

## 🚀 快速安裝 (Quick Start)

請在終端機執行以下指令，下載並執行一鍵安裝腳本。腳本會自動檢查必備工具（如 `jq`），並在背景啟動 Proxy 伺服器。

```bash
chmod +x setup_claude_status.sh
./setup_claude_status.sh
```

## 🛠️ 使用方式 (Usage)

安裝完成後，你只需要讓 Claude Code 知道要走本地代理即可：

### 1. 設定環境變數

在執行 Claude Code 之前，設定 `ANTHROPIC_BASE_URL`。建議將此行加入你的 shell profile 中以永久生效：

```bash
# zsh 使用者
echo 'export ANTHROPIC_BASE_URL="http://localhost:8080"' >> ~/.zshrc

# bash 使用者
echo 'export ANTHROPIC_BASE_URL="http://localhost:8080"' >> ~/.bashrc
```

> 安裝腳本結束時會自動顯示對應你 shell 的一鍵指令，直接複製貼上即可。

### 2. 啟動 Claude Code

```bash
claude
```

### 3. 綁定狀態列

進入 Claude 對話介面後，輸入以下指令綁定剛才生成的腳本：

```bash
/statusline ~/.claude/statusline-command.sh
```

🎉 隨便發送一句話給 Claude，你的狀態列就會立刻亮起！

## 🛑 停止代理伺服器 (Stop Proxy)

如果你想暫時關閉背景的 Proxy 伺服器，只需執行：

```bash
kill $(cat /tmp/claude_proxy.pid) && rm -f /tmp/claude_proxy.pid
```

或使用名稱搜尋：

```bash
pkill -f "node claude-proxy.js"
```

## 📁 檔案說明 (Files)

| 檔案 | 說明 |
|------|------|
| `claude-proxy.js` | Node.js 反向代理，轉發請求至 `api.anthropic.com` 並擷取 Rate Limit Headers，儲存至 `/tmp/claude_rate_limit.json` |
| `setup_claude_status.sh` | 一鍵安裝腳本：自動安裝相依套件、啟動 Proxy、複製 Statusline 腳本 |
| `statusline-command.sh` | Statusline 腳本，顯示模型名稱、Git 分支、Context 使用率、5h / 7d Rate Limit |

## ⚙️ 技術細節 (Technical Details)

* Proxy 監聽 Port `8080`
* Rate Limit 資料儲存路徑：`/tmp/claude_rate_limit.json`
* Proxy PID 記錄路徑：`/tmp/claude_proxy.pid`（供停止/重啟使用）
* `reset_5h` 欄位為 Unix timestamp（非 ISO 8601）
