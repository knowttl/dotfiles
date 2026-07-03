#!/usr/bin/env bash
# tmux-agent-status.sh — per-window coding-agent status glyph for the tmux status
# bar. Reads the glyph published by the daemon (tmux-agent-statusd.sh) for this
# pane, so the status-redraw path stays cheap. Falls back to a one-shot detection
# if the daemon is not running, so the glyph is always correct even without it.
#
# Purely READ-ONLY and DISPLAY-ONLY. It never renames windows, never sets tmux
# options, and never writes tmux state. That is what keeps it safe alongside
# firstmate, which resolves its crew windows by exact window_name.
#
# Self-defending: it resolves its own real path (following the symlink into the
# repo) so it finds its sibling library even if only this file was linked; it
# fails soft to a neutral glyph if the library is unreachable (the bar can never
# break); and it lazily relaunches the daemon if it has died.
#
# Output states (color carries the meaning; glyph is the same ● for agent states):
#   ● peach   busy     — an agent turn is actively streaming
#   ● red     blocked  — an agent is waiting on you (permission / confirm / menu)
#   ● green   idle     — an agent finished its turn; your move, nothing pending
#    muted   term     — no coding-agent process in the pane (shell, vim, build…)
#
# Usage (from the catppuccin window text / window-status-format):
#   #(~/.config/tmux/tmux-agent-status.sh #{pane_id})

set -u

pane=${1:-}
[ -n "$pane" ] || exit 0

# Resolve our REAL location (follow the symlink into the repo) so we find the
# sibling detection library even if only THIS file was linked into
# ~/.config/tmux — e.g. when install.sh was not re-run after a new script was
# added. This is what turns a broken bar into a self-healing one.
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "$SELF")"

# Fail-soft: if the library is somehow still unreachable, draw the neutral
# terminal glyph (nf-cod-terminal U+EA85, built from its UTF-8 bytes so this
# path needs no library) rather than erroring into the status bar. The bar must
# never break — worst case it shows "no agent".
# shellcheck source=/dev/null
if ! . "$SELF_DIR/tmux-agent-detect.sh" 2>/dev/null; then
  printf '#[fg=%s]%b#[fg=%s]' \
    "${TMUX_AGENT_COLOR_TERM:-#9399b2}" '\356\252\205' "${TMUX_AGENT_FG_RESET:-#cdd6f4}"
  exit 0
fi

# Self-heal the daemon if it never started or has died (throttled + flock-deduped).
ensure_daemon

# Fast path: emit the glyph the daemon published for this pane.
cache="$(agent_status_cache_dir)/${pane}.glyph"
if [ -s "$cache" ]; then
  cat "$cache"
  exit 0
fi

# Fallback: daemon not up yet / no cache for this pane. Detect once, statelessly.
# No hysteresis or freeze memory here, so a freeze verdict degrades to idle.
raw=$(detect_pane_raw "$pane")
[ "$raw" = freeze ] && raw=idle
style_glyph "$raw"
