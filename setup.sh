#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 檢查 jq
if ! command -v jq &> /dev/null; then
    echo "⚠️ 找不到 jq，準備自動安裝..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y jq
    else
        echo "❌ 找不到支援的套件管理員，請手動安裝 jq。"
        exit 1
    fi
fi

# 決定安裝目錄
INSTALL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$INSTALL_DIR"

# 選擇進度條樣式
echo ""
echo "請選擇進度條樣式："
echo "  1) ▰▱ 方格（預設）"
echo "  2) ●○ 圓點"
echo "  3) █▌░ 半格精度"
echo -n "請輸入選項 (1/2/3，按 Enter 使用預設): "
read -r STYLE_CHOICE

case "$STYLE_CHOICE" in
    2) BAR_STYLE="circle"    ;;
    3) BAR_STYLE="halfblock" ;;
    *) BAR_STYLE="square"    ;;
esac
echo "✅ 進度條樣式：$BAR_STYLE"

# 複製並設定樣式
cp "$SCRIPT_DIR/statusline-command.sh" "$INSTALL_DIR/statusline-command.sh"
sed -i.bak "s/^BAR_STYLE=.*/BAR_STYLE=\"$BAR_STYLE\"/" "$INSTALL_DIR/statusline-command.sh"
rm -f "$INSTALL_DIR/statusline-command.sh.bak"
chmod +x "$INSTALL_DIR/statusline-command.sh"
echo "✅ 已安裝至 $INSTALL_DIR/statusline-command.sh"

echo ""
echo "👉 進入 Claude Code 後執行以下指令啟用："
echo "   /statusline $INSTALL_DIR/statusline-command.sh"

# Ubuntu GNOME 狀態列指示器
if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v gnome-shell &> /dev/null; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "偵測到 Ubuntu / GNOME 環境"
    echo ""
    echo "是否安裝 Ubuntu 狀態列 Rate Limit 指示器？"
    echo "  功能：在 GNOME 頂部列顯示 ⚡ 8% | 1% ⟳2h30m"
    echo "  需要：gir1.2-ayatana-appindicator3-0.1"
    echo -n "安裝？ (y/N) "
    read -r INDICATOR_CHOICE
    if [[ "$INDICATOR_CHOICE" =~ ^[Yy]$ ]]; then
        bash "$SCRIPT_DIR/ubuntu-indicator/install.sh"
    else
        echo "略過。之後可手動執行："
        echo "  bash $SCRIPT_DIR/ubuntu-indicator/install.sh"
    fi
fi
