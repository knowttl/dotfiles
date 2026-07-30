#!/bin/bash
# Claude Code statusline: model name, context-window usage bar, git status.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // "."')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ANSI colors (dim, since the footer renders dimmed)
C_MODEL='\033[2;36m'   # dim cyan
C_EFFORT='\033[2;34m'  # dim blue
C_BAR='\033[2;33m'     # dim yellow
C_RATE='\033[2;35m'    # dim magenta
C_BRANCH='\033[2;32m'  # dim green
C_DIRTY='\033[2;31m'   # dim red
C_RESET='\033[0m'

# --- Context window usage bar ---
bar_segment=""
if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used")
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  filled=$((pct / 10))
  empty=$((10 - filled))
  filled_str=$(printf '%*s' "$filled" '' | tr ' ' '#')
  empty_str=$(printf '%*s' "$empty" '' | tr ' ' '-')
  bar_segment=$(printf '%b[%s%s] %s%%%b' "$C_BAR" "$filled_str" "$empty_str" "$pct" "$C_RESET")
fi

# --- Rate limit usage (5h session / 7d weekly) ---
rate_segment=""
if [ -n "$five_hour" ]; then
  rate_segment="5h:$(printf '%.0f' "$five_hour")%"
fi
if [ -n "$seven_day" ]; then
  wk="7d:$(printf '%.0f' "$seven_day")%"
  if [ -n "$rate_segment" ]; then
    rate_segment="$rate_segment $wk"
  else
    rate_segment="$wk"
  fi
fi
[ -n "$rate_segment" ] && rate_segment=$(printf '%b%s%b' "$C_RATE" "$rate_segment" "$C_RESET")

# --- Git status ---
git_segment=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  dirty=""
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    dirty=$(printf '%b*%b' "$C_DIRTY" "$C_RESET")
  fi
  git_segment=$(printf '%b%s%b%s' "$C_BRANCH" "$branch" "$C_RESET" "$dirty")
fi

# --- Assemble ---
output=$(printf '%b%s%b' "$C_MODEL" "$model" "$C_RESET")
[ -n "$effort" ] && output=$(printf '%s  %b%s%b' "$output" "$C_EFFORT" "$effort" "$C_RESET")
[ -n "$bar_segment" ] && output="$output  $bar_segment"
[ -n "$rate_segment" ] && output="$output  $rate_segment"
[ -n "$git_segment" ] && output="$output  $git_segment"

printf '%s' "$output"
