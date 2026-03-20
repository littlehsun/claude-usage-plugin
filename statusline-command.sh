#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r 'if .context_window.used_percentage != null then (.context_window.used_percentage + 0.5 | floor) | tostring else empty end')

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
DIM=$'\033[2m'
RESET=$'\033[0m'

color_by_pct() {
    local val=$1
    if [ "$val" -ge 80 ]; then printf "%s" "$RED"
    elif [ "$val" -ge 50 ]; then printf "%s" "$YELLOW"
    else printf "%s" "$GREEN"
    fi
}

[ -n "$branch" ] && branch_part=" | ${CYAN} $branch${RESET}" || branch_part=""

if [ -n "$used_pct" ]; then
    CTX_COLOR=$(color_by_pct "$used_pct")
    ctx_part=" | ctx: ${CTX_COLOR}${used_pct}%${RESET}"
else
    ctx_part=""
fi

# Session count from same dir as this script
LOCK_DIR="$SCRIPT_DIR/claude_proxy_locks"
session_part=""
if [ -d "$LOCK_DIR" ]; then
    SESSION_COUNT=$(find "$LOCK_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$SESSION_COUNT" -gt 0 ] && session_part=" | ✷${SESSION_COUNT}"
fi

# Rate limit from same dir as this script
RL_FILE="$SCRIPT_DIR/claude_rate_limit.json"
rate_part=""
if [ -f "$RL_FILE" ] && command -v jq &>/dev/null; then
    U5H=$(jq -r '.utilization_5h // empty' "$RL_FILE")
    U7D=$(jq -r '.utilization_7d // empty' "$RL_FILE")
    RESET_5H_RAW=$(jq -r '.reset_5h // empty' "$RL_FILE")
    RESET_7D_RAW=$(jq -r '.reset_7d // empty' "$RL_FILE")
    if [ -n "$U5H" ] && [ -n "$U7D" ] && [ -n "$RESET_5H_RAW" ]; then
        INT_5H=$(awk "BEGIN {printf \"%.0f\", $U5H * 100}")
        INT_7D=$(awk "BEGIN {printf \"%.0f\", $U7D * 100}")
        PCT_5H="${INT_5H}%"
        PCT_7D="${INT_7D}%"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            RESET_TIME_5H=$(date -r "$RESET_5H_RAW" "+%H:%M" 2>/dev/null)
            [ -n "$RESET_7D_RAW" ] && RESET_TIME_7D=$(date -r "$RESET_7D_RAW" "+%m/%d %H:%M" 2>/dev/null)
        else
            RESET_TIME_5H=$(date -d "@$RESET_5H_RAW" "+%H:%M" 2>/dev/null)
            [ -n "$RESET_7D_RAW" ] && RESET_TIME_7D=$(date -d "@$RESET_7D_RAW" "+%m/%d %H:%M" 2>/dev/null)
        fi
        C5=$(color_by_pct "$INT_5H")
        C7=$(color_by_pct "$INT_7D")
        R7_PART=""
        [ -n "$RESET_TIME_7D" ] && R7_PART="${DIM}(↺${RESET_TIME_7D})${RESET}"
        rate_part=" | ⚡ 5h:${C5}${PCT_5H}${RESET}${DIM}(↺${RESET_TIME_5H})${RESET} 7d:${C7}${PCT_7D}${RESET}${R7_PART}"
    fi
fi

printf "%s%s%s%s%s" "$model" "$branch_part" "$ctx_part" "$session_part" "$rate_part"
