#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# 步驟 2：驗證 Proxy 腳本存在
# ==========================================
if [ ! -f "$SCRIPT_DIR/claude-proxy.js" ]; then
    echo -e "\033[31m[錯誤] 找不到 $SCRIPT_DIR/claude-proxy.js\033[0m"
    exit 1
fi

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

cp "$SCRIPT_DIR/claude-proxy.js" ~/.claude/claude-proxy.js
echo "✅ Proxy 腳本已複製至 ~/.claude/claude-proxy.js！"

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
echo "👉 下一步，請將 claude wrapper 寫入 shell profile，之後直接執行 claude 即可："
echo "   claude"
echo ""
AUTOSTART_SNIPPET='# claude-proxy wrapper - 執行 claude 時才啟動 proxy，結束後自動停止
claude() {
    local PROXY_PID_FILE="/tmp/claude_proxy.pid"
    local LOCK_DIR="/tmp/claude_proxy_locks"
    local LOCK_FILE="$LOCK_DIR/$$"
    local PROXY_SCRIPT="$HOME/.claude/claude-proxy.js"

    mkdir -p "$LOCK_DIR"

    # 清除 stale locks（PID 已不存在的）
    if [ -n "$(ls -A "$LOCK_DIR" 2>/dev/null)" ]; then
        for f in "$LOCK_DIR"/*; do
            [ -f "$f" ] && ! kill -0 "$(basename "$f")" 2>/dev/null && rm -f "$f"
        done
    fi

    touch "$LOCK_FILE"

    # 若 proxy 尚未啟動則啟動，否則沿用現有的
    local _PROXY_PID
    _PROXY_PID=$(cat "$PROXY_PID_FILE" 2>/dev/null)
    if [ -z "$_PROXY_PID" ] || ! kill -0 "$_PROXY_PID" 2>/dev/null; then
        nohup node "$PROXY_SCRIPT" > /dev/null 2>&1 &
        echo $! > "$PROXY_PID_FILE"
    fi

    _claude_cleanup() {
        rm -f "$LOCK_FILE"
        # lock 目錄空了才代表沒有其他 claude 在跑
        if [ -z "$(ls -A "$LOCK_DIR" 2>/dev/null)" ]; then
            kill "$(cat "$PROXY_PID_FILE" 2>/dev/null)" 2>/dev/null || pkill -f "claude-proxy.js" 2>/dev/null
            rm -f "$PROXY_PID_FILE"
            rmdir "$LOCK_DIR" 2>/dev/null
        fi
        trap - INT TERM
    }
    trap _claude_cleanup INT TERM

    ANTHROPIC_BASE_URL="http://localhost:19999" command claude "$@"
    _claude_cleanup
}'

if [ -n "$SHELL_PROFILE" ]; then
    echo -n "💡 是否將 Proxy 自動啟動寫入 $SHELL_PROFILE？(y/N) "
    read -r REPLY
    case "$REPLY" in
        [yY])
            if grep -q "# claude-proxy wrapper" "$SHELL_PROFILE" 2>/dev/null; then
                # 移除舊的 claude wrapper（從標記注解到函式結尾的 `}`）
                awk '/^# claude-proxy wrapper/{found=1; next} found && /^}/{found=0; next} found{next} {print}' \
                    "$SHELL_PROFILE" > /tmp/_claude_profile_tmp && mv /tmp/_claude_profile_tmp "$SHELL_PROFILE"
                echo "🔄 偵測到已存在的 claude wrapper，已取代為最新版本！"
            fi
            echo "$AUTOSTART_SNIPPET" >> "$SHELL_PROFILE"
            echo "✅ 已寫入 $SHELL_PROFILE！"
            echo "👉 請執行以下指令讓設定立即生效："
            echo "   source $SHELL_PROFILE"
            ;;
        *)
            echo "💡 若之後想手動加入，可執行："
            echo ""
            echo "   cat >> $SHELL_PROFILE << 'EOF'"
            echo "$AUTOSTART_SNIPPET"
            echo "EOF"
            ;;
    esac
else
    echo "💡 若要每次開 terminal 自動啟動 Proxy 並設定環境變數，可執行："
    echo ""
    echo "   # zsh 使用者："
    echo "   cat >> ~/.zshrc << 'EOF'"
    echo "$AUTOSTART_SNIPPET"
    echo "EOF"
    echo ""
    echo "   # bash 使用者："
    echo "   cat >> ~/.bashrc << 'EOF'"
    echo "$AUTOSTART_SNIPPET"
    echo "EOF"
fi
echo ""
echo "👉 進入 Claude 後，輸入以下指令綁定狀態列："
echo "   /statusline ~/.claude/statusline-command.sh"
