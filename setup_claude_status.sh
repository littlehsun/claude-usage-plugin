#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_PID_FILE="/tmp/claude_proxy.pid"

# ==========================================
# 步驟 1：自動檢查並安裝必備工具 (jq, node)
# ==========================================
echo "🔍 正在檢查必備套件..."
if ! command -v jq &> /dev/null; then
    echo "⚠️ 找不到 jq，準備自動安裝..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "🍏 偵測到 macOS，使用 Homebrew 安裝 jq..."
        brew install jq
    elif command -v apt &> /dev/null; then
        echo "🐧 偵測到 Ubuntu/Debian，使用 apt 安裝 (可能需要輸入密碼)..."
        sudo apt update && sudo apt install -y jq
    else
        echo -e "\033[31m[錯誤] 找不到支援的套件管理員 (brew 或 apt)，請手動安裝 jq。\033[0m"
        exit 1
    fi
    echo "✅ jq 安裝完成！"
else
    echo "✅ jq 已安裝，略過！"
fi

if ! command -v node &> /dev/null; then
    echo -e "\033[31m[錯誤] 找不到 node，請先安裝 Node.js。\033[0m"
    exit 1
fi
echo "✅ node 已安裝，略過！"

# ==========================================
# 步驟 2：啟動 Proxy 腳本
# ==========================================
echo "⚙️ 正在啟動 Proxy 代理伺服器..."

if [ ! -f "$SCRIPT_DIR/claude-proxy.js" ]; then
    echo -e "\033[31m[錯誤] 找不到 $SCRIPT_DIR/claude-proxy.js\033[0m"
    exit 1
fi

# 用 PID 檔案精準停掉舊的 proxy
if [ -f "$PROXY_PID_FILE" ]; then
    OLD_PID=$(cat "$PROXY_PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null
    fi
    rm -f "$PROXY_PID_FILE"
fi

nohup node "$SCRIPT_DIR/claude-proxy.js" > /dev/null 2>&1 &
PROXY_PID=$!
echo "$PROXY_PID" > "$PROXY_PID_FILE"

# 確認 proxy 真的啟動成功
sleep 1
if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    echo -e "\033[31m[錯誤] Proxy 啟動失敗。\033[0m"
    rm -f "$PROXY_PID_FILE"

    # 檢查 Port 8080 是否被佔用
    PORT_PID=$(lsof -ti :8080 2>/dev/null)
    if [ -n "$PORT_PID" ]; then
        PORT_CMD=$(ps -p "$PORT_PID" -o comm= 2>/dev/null)
        echo -e "\033[33m⚠️  Port 8080 已被其他 process 佔用（PID: $PORT_PID, 程式: $PORT_CMD）\033[0m"
        echo ""
        echo "💡 建議執行以下指令來釋放 Port 並重新啟動："
        echo "   kill $PORT_PID && bash $0"
        echo ""
        echo "   或強制終止："
        echo "   kill -9 $PORT_PID && bash $0"
    else
        echo "💡 Port 8080 未被佔用，請檢查 claude-proxy.js 是否有其他錯誤。"
        echo "   手動測試：node $SCRIPT_DIR/claude-proxy.js"
    fi
    exit 1
fi
echo "✅ 代理伺服器已在背景無痕運行！(Port: 8080, PID: $PROXY_PID)"

# ==========================================
# 步驟 3：複製 Statusline 腳本
# ==========================================
echo "📝 正在複製 Claude Statusline 腳本..."

if [ ! -f "$SCRIPT_DIR/statusline-command.sh" ]; then
    echo -e "\033[31m[錯誤] 找不到 $SCRIPT_DIR/statusline-command.sh\033[0m"
    exit 1
fi

mkdir -p ~/.claude
cp "$SCRIPT_DIR/statusline-command.sh" ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
echo "✅ Statusline 腳本設定完成！"

# ==========================================
# 偵測使用者 Shell Profile
# ==========================================
detect_shell_profile() {
    if [[ "$SHELL" == */zsh ]]; then
        echo "$HOME/.zshrc"
    elif [[ "$SHELL" == */bash ]]; then
        echo "$HOME/.bashrc"
    else
        echo ""
    fi
}

SHELL_PROFILE=$(detect_shell_profile)

# ==========================================
# 總結提示
# ==========================================
echo ""
echo "🎉 所有安裝皆已完成！"
echo "👉 下一步，請在你的終端機輸入以下指令啟動 Claude："
echo "   export ANTHROPIC_BASE_URL=\"http://localhost:8080\""
echo "   claude"
echo ""
if [ -n "$SHELL_PROFILE" ]; then
    echo "💡 若要永久生效（寫入 $SHELL_PROFILE），可執行："
    echo "   echo 'export ANTHROPIC_BASE_URL=\"http://localhost:8080\"' >> $SHELL_PROFILE"
else
    echo "💡 若要永久生效，請手動將以下內容加入你的 shell profile："
    echo "   export ANTHROPIC_BASE_URL=\"http://localhost:8080\""
    echo "   （~/.zshrc 或 ~/.bashrc，依你使用的 shell 而定）"
fi
echo ""
echo "👉 進入 Claude 後，輸入以下指令綁定狀態列："
echo "   /statusline ~/.claude/statusline-command.sh"
