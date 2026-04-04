#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin/claude-rate-indicator"
AUTOSTART="$HOME/.config/autostart/claude-rate-indicator.desktop"

echo "=== Claude Rate Limit Indicator 安裝 ==="

# 1. 相依套件
echo "[1/4] 檢查相依套件..."
if ! python3 -c "import gi; gi.require_version('AppIndicator3','0.1'); from gi.repository import AppIndicator3" 2>/dev/null; then
    echo "  安裝 gir1.2-ayatana-appindicator3-0.1..."
    sudo apt-get install -y gir1.2-ayatana-appindicator3-0.1
else
    echo "  AppIndicator3 已存在"
fi

# 2. 複製執行檔
echo "[2/4] 安裝執行檔..."
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/indicator.py" "$BIN"
chmod +x "$BIN"

# 3. 安裝圖示
echo "[3/4] 安裝圖示..."
ICON_DEST="$HOME/.local/share/icons/claude-rate-indicator"
mkdir -p "$ICON_DEST"
cp "$SCRIPT_DIR/icons/"*.svg "$ICON_DEST/"

# 4. Autostart
echo "[4/4] 設定開機自動啟動..."
mkdir -p "$HOME/.config/autostart"
cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=Claude Rate Indicator
Comment=Claude Code rate limit indicator for GNOME
Exec=python3 $BIN
Icon=$ICON_DEST/claude-rate-green.svg
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo ""
echo "安裝完成！"
echo ""
echo "啟動指示器："
echo "  python3 $BIN &"
echo ""
echo "（下次登入會自動啟動）"
echo ""

# 詢問是否立即啟動
read -r -p "現在啟動？ (y/N) " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    # 關掉舊的
    pkill -f "claude-rate-indicator" 2>/dev/null || true
    sleep 0.5
    python3 "$BIN" &
    echo "指示器已啟動（PID $!）"
fi
