# Claude Code Enhanced Statusline ⚡

A lightweight statusline for **Claude Code** that displays model, git branch, context usage, concurrent sessions, and accurate rate limits for Pro / Max tiers.
專為 Claude Code 設計的增強狀態列，顯示模型名稱、Git 分支、Context 使用率、並行 Session 數，以及 Pro / Max 方案的精準速率限制。

## 💡 為什麼需要這個專案？ (Why?)

目前 Claude Code 官方的 `/statusline` API 並未提供具體的 Rate Limit 數據。如果寫腳本頻繁去戳官方的 Usage API，會極易觸發 `429 Too Many Requests` 封鎖。

**本專案的解法：**
透過在本地端建立一個極輕量的 Node.js 反向代理（Reverse Proxy），攔截並解析 Anthropic 官方 API 在正常對話中回傳的 `anthropic-ratelimit-unified-*` Headers，並轉化為原生 Statusline 可讀的格式。

## ✨ 特色 (Features)

* **🚫 無痛繞過 429 封鎖**：不發送任何額外查詢請求，完全依賴正常對話的攔截。
* **🎯 100% 官方精確數據**：直接讀取伺服器端 Unified Rate Limit，非本地端推算。
* **🌈 視覺化狀態列**：動態顏色顯示 5h 與 7d 剩餘額度百分比與重置時間（超過 50% 轉黃、80% 亮紅燈）。
* **✷ 並行 Session 計數**：同時開多個 Claude 視窗時，狀態列顯示目前活躍的 Session 數量。
* **🔄 按需啟動代理**：執行 `claude` 時自動啟動 Proxy，所有 Claude 視窗關閉後自動停止，不佔用資源。
* **👻 無痕背景執行**：所有的輸出導向 `/dev/null`，不佔用硬碟產生 Log 檔。
* **🐧 雙平台支援**：自動相容 macOS 與 Ubuntu/Linux 環境。

## 🚀 快速安裝 (Quick Start)

請在終端機執行以下指令，下載並執行一鍵安裝腳本。腳本會自動檢查必備工具（如 `jq`），並複製必要腳本。

```bash
chmod +x setup_claude_status.sh
./setup_claude_status.sh
```

## 🛠️ 使用方式 (Usage)

安裝完成後，將 claude wrapper 寫入 shell profile，之後直接執行 `claude` 即可。

### 1. 設定 Claude Wrapper

安裝腳本結束時會偵測你的 shell profile（`~/.zshrc` 或 `~/.bashrc`），並詢問是否直接寫入：

```
💡 是否將 Proxy 自動啟動寫入 ~/.zshrc？(y/N)
```

- 選 `y`：自動寫入，並提示執行 `source ~/.zshrc` 讓設定立即生效
- 選 `N`（預設）：顯示手動加入的指令供複製貼上
- 若無法偵測 shell：分別列出 zsh 與 bash 兩種版本

寫入後，執行 `claude` 時會自動啟動 Proxy（若尚未啟動），並設定 `ANTHROPIC_BASE_URL=http://localhost:19999`。當所有 Claude 視窗都關閉時，Proxy 會自動停止。

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

狀態列格式範例：
```
claude-sonnet-4-5 |  main | ctx: 12% | ✷2 | ⚡ 5h:34%(↺14:30) 7d:8%(↺03/20 09:00)
```

## 🛑 停止代理伺服器 (Stop Proxy)

正常情況下，Proxy 會在最後一個 Claude 視窗關閉時自動停止。若需要手動強制關閉：

```bash
kill $(cat /tmp/claude_proxy.pid) && rm -f /tmp/claude_proxy.pid
```

或使用名稱搜尋：

```bash
pkill -f "claude-proxy.js"
```

## 📁 檔案說明 (Files)

| 檔案 | 說明 |
|------|------|
| `claude-proxy.js` | Node.js 反向代理，轉發請求至 `api.anthropic.com` 並擷取 Rate Limit Headers，儲存至 `/tmp/claude_rate_limit.json` |
| `setup_claude_status.sh` | 一鍵安裝腳本：自動安裝相依套件、複製 Statusline 與 Proxy 腳本，並將 claude wrapper 寫入 shell profile |
| `statusline-command.sh` | Statusline 腳本，顯示模型名稱、Git 分支、Context 使用率、並行 Session 數、5h / 7d Rate Limit |

## ⚙️ 技術細節 (Technical Details)

* Proxy 監聽 Port `19999`
* Rate Limit 資料儲存路徑：`/tmp/claude_rate_limit.json`
* Proxy PID 記錄路徑：`/tmp/claude_proxy.pid`（供停止/重啟使用）
* Session Lock 目錄：`/tmp/claude_proxy_locks/`（每個 claude 執行實例建立一個 lock 檔，全部結束後 Proxy 自動停止）
* `reset_5h` 與 `reset_7d` 欄位皆為 Unix timestamp（非 ISO 8601）
* Statusline 顯示格式：`<model> | <branch> | ctx:<pct>% | ✷<sessions> | ⚡ 5h:<used>%(↺HH:MM) 7d:<used>%(↺MM/DD HH:MM)`
* 若 Port `19999` 已被占用，啟動腳本會自動偵測並顯示占用的 PID 與程式名稱
