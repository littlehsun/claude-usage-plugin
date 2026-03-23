#!/usr/bin/env bash
# BAR_STYLE: square (default) | circle | halfblock
BAR_STYLE="square"

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r 'if .context_window.used_percentage != null then (.context_window.used_percentage + 0.5 | floor) | tostring else empty end')

# RGB colors
BLUE=$'\033[38;2;0;153;255m'
ORANGE=$'\033[38;2;255;176;85m'
GREEN=$'\033[38;2;0;175;80m'
CYAN=$'\033[38;2;86;182;194m'
RED=$'\033[38;2;255;85;85m'
YELLOW=$'\033[38;2;230;200;0m'
WHITE=$'\033[38;2;220;220;220m'
DIM=$'\033[2m'
RESET=$'\033[0m'

color_for_pct() {
    local val=$1
    if [ "$val" -ge 90 ]; then printf "%s" "$RED"
    elif [ "$val" -ge 70 ]; then printf "%s" "$YELLOW"
    elif [ "$val" -ge 50 ]; then printf "%s" "$ORANGE"
    else printf "%s" "$GREEN"
    fi
}

build_bar() {
    local pct=$1 color=$2 filled_char=$3 empty_char=$4
    local filled=$((pct * 10 / 100))
    local empty=$((10 - filled))
    local bar="" i
    for ((i=0; i<filled; i++)); do bar="${bar}${filled_char}"; done
    for ((i=0; i<empty; i++)); do bar="${bar}${empty_char}"; done
    printf "%s%s%s" "$color" "$bar" "$RESET"
}

build_bar_half() {
    local pct=$1 color=$2
    local full=$((pct / 10))
    local half=$(( (pct % 10) >= 5 ? 1 : 0 ))
    local empty=$((10 - full - half))
    local bar="" i
    for ((i=0; i<full; i++));  do bar="${bar}█"; done
    [ "$half" -eq 1 ]          && bar="${bar}▌"
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    printf "%s%s%s" "$color" "$bar" "$RESET"
}

SEP=" ${DIM}│${RESET} "

# Folder + branch + git status
folder=$(basename "$cwd")
if [ -n "$branch" ]; then
    STAGED=$(git -C "$cwd" --no-optional-locks diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "$cwd" --no-optional-locks diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    UNTRACKED=$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    AHEAD=$(git -C "$cwd" --no-optional-locks rev-list --count @{upstream}..HEAD 2>/dev/null)
    BEHIND=$(git -C "$cwd" --no-optional-locks rev-list --count HEAD..@{upstream} 2>/dev/null)
    git_status=""
    [ "$STAGED" -gt 0 ]   && git_status="${git_status} ${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && git_status="${git_status} ${YELLOW}!${MODIFIED}${RESET}"
    [ "$UNTRACKED" -gt 0 ] && git_status="${git_status} ${DIM}?${UNTRACKED}${RESET}"
    [ -n "$AHEAD" ]  && [ "$AHEAD" -gt 0 ]  && git_status="${git_status} ${CYAN}↑${AHEAD}${RESET}"
    [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ] && git_status="${git_status} ${RED}↓${BEHIND}${RESET}"
    branch_part="${SEP}${CYAN}${folder}  ${branch}${RESET}${git_status}"
else
    branch_part="${SEP}${DIM}${folder}${RESET}"
fi

# Worktree
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')
[ -n "$worktree_name" ] && worktree_part="${SEP}⑂ ${worktree_name}" || worktree_part=""

# Context
ctx_part=""
if [ -n "$used_pct" ]; then
    CTX_COLOR=$(color_for_pct "$used_pct")
    ctx_part="${SEP}✍ ${CTX_COLOR}${used_pct}%${RESET}"
fi

# Line 1
printf "%s%s%s%s\n" "${WHITE}${model}${RESET}" "$branch_part" "$worktree_part" "$ctx_part"

# Rate limits - Line 2
U5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
U7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
RESET_5H_RAW=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RESET_7D_RAW=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$U5H" ] && [ -n "$U7D" ]; then
    INT_5H=$(awk "BEGIN {printf \"%.0f\", $U5H}")
    INT_7D=$(awk "BEGIN {printf \"%.0f\", $U7D}")
    C5=$(color_for_pct "$INT_5H")
    C7=$(color_for_pct "$INT_7D")
    case "$BAR_STYLE" in
        circle)    BAR_5H=$(build_bar "$INT_5H" "$C5" "●" "○"); BAR_7D=$(build_bar "$INT_7D" "$C7" "●" "○") ;;
        halfblock) BAR_5H=$(build_bar_half "$INT_5H" "$C5");    BAR_7D=$(build_bar_half "$INT_7D" "$C7")    ;;
        *)         BAR_5H=$(build_bar "$INT_5H" "$C5" "▰" "▱"); BAR_7D=$(build_bar "$INT_7D" "$C7" "▰" "▱") ;;
    esac
    NOW=$(date +%s)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        [ -n "$RESET_5H_RAW" ] && RESET_TIME_5H=$(date -r "$RESET_5H_RAW" "+%H:%M" 2>/dev/null)
        [ -n "$RESET_7D_RAW" ] && RESET_TIME_7D=$(date -r "$RESET_7D_RAW" "+%m/%d %H:%M" 2>/dev/null)
    else
        [ -n "$RESET_5H_RAW" ] && RESET_TIME_5H=$(date -d "@$RESET_5H_RAW" "+%H:%M" 2>/dev/null)
        [ -n "$RESET_7D_RAW" ] && RESET_TIME_7D=$(date -d "@$RESET_7D_RAW" "+%m/%d %H:%M" 2>/dev/null)
    fi
    fmt_countdown() {
        local secs=$(( $1 - NOW ))
        [ "$secs" -le 0 ] && echo "soon" && return
        local d=$(( secs / 86400 ))
        local h=$(( (secs % 86400) / 3600 ))
        local m=$(( (secs % 3600) / 60 ))
        if [ "$d" -gt 0 ]; then echo "${d}d${h}h"
        elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
        else echo "${m}m"
        fi
    }
    R5="" R7=""
    if [ -n "$RESET_5H_RAW" ] && [ -n "$RESET_TIME_5H" ]; then
        CD5=$(fmt_countdown "$RESET_5H_RAW")
        R5="${DIM} ⟳ ${CD5} (${RESET_TIME_5H})${RESET}"
    fi
    if [ -n "$RESET_7D_RAW" ] && [ -n "$RESET_TIME_7D" ]; then
        R7="${DIM} ⟳ ${RESET_TIME_7D}${RESET}"
    fi
    printf "${DIM}5H${RESET} %s ${C5}%s%%${RESET}%s ${DIM}7D${RESET} %s ${C7}%s%%${RESET}%s\n" \
        "$BAR_5H" "$INT_5H" "$R5" "$BAR_7D" "$INT_7D" "$R7"
fi
