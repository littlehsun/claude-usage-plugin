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
# 步驟 3：驗證 Statusline 腳本存在
# ==========================================
if [ ! -f "$SCRIPT_DIR/statusline-command.sh" ]; then
    echo -e "\033[31m[錯誤] 找不到 $SCRIPT_DIR/statusline-command.sh\033[0m"
    exit 1
fi

# ==========================================
# 步驟 3a：決定安裝目錄
# ==========================================
INSTALL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
echo "📁 安裝目錄：$INSTALL_DIR"

# ==========================================
# 步驟 3b：決定 Proxy Port
# ==========================================
DEFAULT_PORT=19999

is_port_free() {
    ! nc -z localhost "$1" 2>/dev/null
}

is_our_proxy() {
    lsof -ti tcp:"$DEFAULT_PORT" 2>/dev/null | xargs -I{} ps -p {} -o args= 2>/dev/null | grep -q "$INSTALL_DIR/claude-proxy.js"
}

find_available_ports() {
    local count=0 port=20000
    local found=()
    while [ $count -lt 3 ]; do
        if is_port_free $port; then
            found+=($port)
            ((count++))
        fi
        ((port++))
    done
    echo "${found[@]}"
}

if is_port_free $DEFAULT_PORT; then
    PROXY_PORT=$DEFAULT_PORT
    echo "🔌 使用 Port $PROXY_PORT"
elif is_our_proxy; then
    PROXY_PORT=$DEFAULT_PORT
    echo "🔌 Port $DEFAULT_PORT 已有此目錄的 proxy 在運行，沿用。"
else
    OCCUPYING=$(lsof -ti tcp:"$DEFAULT_PORT" 2>/dev/null | xargs -I{} ps -p {} -o pid=,args= 2>/dev/null | head -1)
    echo "⚠️  Port $DEFAULT_PORT 已被其他程序占用：$OCCUPYING"
    echo "   請選擇可用的 Port："
    read -ra AVAILABLE_PORTS <<< "$(find_available_ports)"
    echo "   A) ${AVAILABLE_PORTS[0]}"
    echo "   B) ${AVAILABLE_PORTS[1]}"
    echo "   C) ${AVAILABLE_PORTS[2]}"
    echo "   或直接輸入自訂 Port"
    while true; do
        echo -n "請選擇 (A/B/C 或輸入 Port): "
        read -r PORT_CHOICE
        case "${PORT_CHOICE^^}" in
            A) PROXY_PORT="${AVAILABLE_PORTS[0]}"; break ;;
            B) PROXY_PORT="${AVAILABLE_PORTS[1]}"; break ;;
            C) PROXY_PORT="${AVAILABLE_PORTS[2]}"; break ;;
            *)
                if ! [[ "$PORT_CHOICE" =~ ^[0-9]+$ ]] || [ "$PORT_CHOICE" -lt 1 ] || [ "$PORT_CHOICE" -gt 65535 ]; then
                    echo "❌ 無效的 Port（需為 1–65535），請重新輸入。"
                elif ! is_port_free "$PORT_CHOICE"; then
                    OCCUPYING=$(lsof -ti tcp:"$PORT_CHOICE" 2>/dev/null | xargs -I{} ps -p {} -o pid=,args= 2>/dev/null | head -1)
                    echo "❌ Port $PORT_CHOICE 已被占用：$OCCUPYING，請重新輸入。"
                else
                    PROXY_PORT="$PORT_CHOICE"; break
                fi
                ;;
        esac
    done
fi

# ==========================================
# 步驟 3c：複製腳本並寫入 port
# ==========================================
echo "📝 正在複製 Claude Statusline 腳本至 $INSTALL_DIR ..."

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/statusline-command.sh" "$INSTALL_DIR/statusline-command.sh"
chmod +x "$INSTALL_DIR/statusline-command.sh"
echo "✅ Statusline 腳本設定完成！"

cp "$SCRIPT_DIR/claude-proxy.js" "$INSTALL_DIR/claude-proxy.js"
echo "✅ Proxy 腳本已複製至 $INSTALL_DIR/claude-proxy.js！"

echo "$PROXY_PORT" > "$INSTALL_DIR/proxy_port"
echo "✅ Port $PROXY_PORT 已寫入 $INSTALL_DIR/proxy_port"

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
    local CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    local PROXY_SCRIPT="$CONFIG_DIR/claude-proxy.js"
    local PROXY_PORT
    PROXY_PORT=$(cat "$CONFIG_DIR/proxy_port" 2>/dev/null || echo 19999)
    local PROXY_PID_FILE="$CONFIG_DIR/claude_proxy.pid"
    local LOCK_DIR="$CONFIG_DIR/claude_proxy_locks"
    local LOCK_FILE="$LOCK_DIR/$$"

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
        nohup node "$PROXY_SCRIPT" "$PROXY_PORT" > /dev/null 2>&1 &
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

    ANTHROPIC_BASE_URL="http://localhost:$PROXY_PORT" command claude "$@"
    _claude_cleanup
}
# end claude-proxy wrapper'

if [ -n "$SHELL_PROFILE" ]; then
    if grep -q "# claude-proxy wrapper" "$SHELL_PROFILE" 2>/dev/null; then
        EXISTING_SNIPPET=$(awk '
            /^# claude-proxy wrapper/ { in_block=1 }
            in_block { print }
            /^# end claude-proxy wrapper/ { in_block=0 }
        ' "$SHELL_PROFILE")
        if [ "$EXISTING_SNIPPET" = "$AUTOSTART_SNIPPET" ]; then
            echo "✅ $SHELL_PROFILE 已有最新版 claude wrapper，略過。"
            REPLY="n"
        else
            echo -n "⚠️  偵測到 $SHELL_PROFILE 已有舊版 claude wrapper，是否更新？(Y/n) "
            read -r REPLY
        fi
    else
        echo -n "💡 是否將 Proxy 自動啟動寫入 $SHELL_PROFILE？(Y/n) "
        read -r REPLY
    fi
    case "${REPLY:-y}" in
        [yY])
            if grep -q "# claude-proxy wrapper" "$SHELL_PROFILE" 2>/dev/null; then
                # 移除舊的 claude wrapper（介於開始與結束標記之間的區塊）
                tmp_profile="$(mktemp "${TMPDIR:-/tmp}/_claude_profile_tmp.XXXXXX")" || {
                     echo "❌ 無法建立暫存檔，請稍後再試。"
                     exit 1
                 }
                 trap 'rm -f "$tmp_profile"' EXIT
                
                if awk '
                    /^# claude-proxy wrapper/ { in_block = 1; next }
                    /^# end claude-proxy wrapper/ {
                        if (in_block) {
                            in_block = 0;
                            next;
                        }
                    }
                    {
                        if (!in_block) {
                            print;
                        }
                    }
                    END {
                        if (in_block) {
                            print "Warning: failed to fully remove existing claude wrapper: missing end marker # end claude-proxy wrapper" > "/dev/stderr";
                            exit 1;
                        }
                    }
                '  "$SHELL_PROFILE" > "$tmp_profile"; then
                # awk 成功才覆蓋檔案並解除 trap（保留原始檔案權限）
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    chmod "$(stat -f "%Lp" "$SHELL_PROFILE")" "$tmp_profile"
                else
                    chmod "$(stat -c "%a" "$SHELL_PROFILE")" "$tmp_profile"
                fi
                mv "$tmp_profile" "$SHELL_PROFILE" && trap - EXIT
                echo "🔄 偵測到已存在的 claude wrapper，已取代為最新版本！"
               else
                   # awk 失敗（例如找不到結尾標記）時的處理
                   echo "❌ 移除舊版 wrapper 發生錯誤，安裝已中斷。"
                   echo "👉 請手動開啟 $SHELL_PROFILE 清理不完整的 claude-proxy wrapper 區塊後再試一次。"
                   exit 1
                fi
            fi
            echo "$AUTOSTART_SNIPPET" >> "$SHELL_PROFILE"
            echo "✅ 已寫入 $SHELL_PROFILE！"
            echo "👉 請執行以下指令讓設定立即生效："
            echo "   source $SHELL_PROFILE"
            ;;
        *)
            SNIPPET_FILE="$INSTALL_DIR/claude-wrapper.snippet"
            echo "$AUTOSTART_SNIPPET" > "$SNIPPET_FILE"
            echo "💡 若之後想手動加入，請將以下內容貼入 $SHELL_PROFILE："
            echo "   $SNIPPET_FILE"
            ;;
    esac
else
    SNIPPET_FILE="$INSTALL_DIR/claude-wrapper.snippet"
    echo "$AUTOSTART_SNIPPET" > "$SNIPPET_FILE"
    echo "💡 若要手動加入 wrapper，請將以下檔案內容貼入你的 shell profile："
    echo "   $SNIPPET_FILE"
fi
echo ""
echo "👉 進入 Claude 後，輸入以下指令綁定狀態列："
echo "   /statusline $INSTALL_DIR/statusline-command.sh"
