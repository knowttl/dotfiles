#!/usr/bin/env bash
# tmux-agent-statusd.sh — background poller that keeps per-pane coding-agent state
# and publishes a styled status glyph per pane. The tmux status bar reads the
# published glyph via tmux-agent-status.sh (a trivial cat), so the expensive
# detection work happens here on a fast loop instead of in the status-redraw path.
#
# This is the herdr polling model translated to shell:
#   * Poll every ~300ms; keep per-pane state in RAM (bash associative arrays).
#   * Publish `working`/`blocked` immediately (no debounce on entry).
#   * Debounce ONLY working -> idle: require N consecutive idle reads before
#     flipping, to swallow transient blank redraw frames (herdr's
#     PendingIdleConfirmation).
#   * A 3-second startup grace after an agent appears suppresses a `blocked`
#     verdict from a half-painted TUI (herdr's startup grace window).
#   * A `freeze` verdict (transcript viewer / model picker) holds the last real
#     state instead of overwriting it (herdr's skip_state_update).
#   * Skip the (relatively) expensive screen capture for a pane that is already
#     idle and whose pane_activity has not advanced (herdr's content-seq gate).
#   * On any published change, nudge the attached clients to redraw so the new
#     glyph appears without waiting for the next status-interval tick.
#
# Safety: this NEVER renames a window, sets a tmux option, or writes window_name.
# It only reads panes and writes glyph files under a private runtime dir, so it is
# completely decoupled from firstmate (which resolves crew windows by window_name).

set -u

# Resolve our real location (follow the symlink into the repo) so we find the
# sibling detection library even if only this file was linked into ~/.config/tmux.
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "$SELF")"
# shellcheck source=/dev/null
. "$SELF_DIR/tmux-agent-detect.sh" 2>/dev/null || exit 0

POLL_INTERVAL=${TMUX_AGENT_POLL_INTERVAL:-0.3}   # base poll cadence (seconds)
IDLE_CONFIRMATIONS=${TMUX_AGENT_IDLE_CONFIRMATIONS:-3}  # working->idle debounce
STARTUP_GRACE=${TMUX_AGENT_STARTUP_GRACE:-3}     # seconds to suppress startup blocked

CACHE_DIR="$(agent_status_cache_dir)"
LOCK_FILE="$CACHE_DIR/.daemon.lock"
PID_FILE="$CACHE_DIR/.daemon.pid"

mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0

# --- single instance --------------------------------------------------------
# flock keeps a second daemon from starting (e.g. when tmux.conf is re-sourced,
# or when several readers race to lazy-launch a dead daemon at once).
exec 9>"$LOCK_FILE" 2>/dev/null || exit 0
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi

# Publish our pid so the reader can tell whether the daemon is alive and, if not,
# relaunch it. Removed on shutdown so a dead daemon leaves no stale liveness.
printf '%s' "$$" > "$PID_FILE" 2>/dev/null

cleanup() { rm -f "$CACHE_DIR"/*.glyph "$PID_FILE" 2>/dev/null; }
trap 'cleanup; exit 0' INT TERM

# --- per-pane state (in RAM) ------------------------------------------------
declare -A PUB          # last published logical state: term|blocked|busy|idle
declare -A PEND         # consecutive idle reads while holding busy (debounce)
declare -A FIRST        # SECONDS when the agent first appeared (startup grace)
declare -A ACT          # last pane_activity we captured at (content-change gate)
declare -A WRITTEN      # last styled glyph string written to the cache file
declare -A ALIVE        # marks panes seen this pass, to prune the rest

# apply_hysteresis <pane> <raw> <activity>: fold the raw per-poll verdict into the
# published logical state, applying freeze / grace / working->idle debounce.
# Echoes the logical state to publish.
apply_hysteresis() {
  local pane=$1 raw=$2 prev=${PUB[$pane]:-term}

  # No agent: reset all per-pane memory and publish term.
  if [ "$raw" = term ]; then
    unset "FIRST[$pane]"; PEND[$pane]=0; PUB[$pane]=term
    echo term; return
  fi

  # Freeze: untrusted screen — hold the last real state (idle if none yet).
  if [ "$raw" = freeze ]; then
    if [ -n "${PUB[$pane]:-}" ] && [ "$prev" != term ]; then echo "$prev"; return; fi
    raw=idle
  fi

  # First sighting of an agent in this pane starts the startup-grace clock.
  [ -n "${FIRST[$pane]:-}" ] || FIRST[$pane]=$SECONDS

  # Startup grace: a freshly-launched TUI can paint a prompt-box that looks like
  # a confirmation dialog; suppress `blocked` (but not busy) for the grace window.
  if [ "$raw" = blocked ] && (( SECONDS - FIRST[$pane] < STARTUP_GRACE )); then
    raw=idle
  fi

  # Debounce working -> idle only: require IDLE_CONFIRMATIONS consecutive idle
  # reads before flipping. blocked/busy are published immediately (below).
  if [ "$prev" = busy ] && [ "$raw" = idle ]; then
    PEND[$pane]=$(( ${PEND[$pane]:-0} + 1 ))
    if (( PEND[$pane] < IDLE_CONFIRMATIONS )); then echo busy; return; fi
    PEND[$pane]=0; PUB[$pane]=idle; echo idle; return
  fi

  PEND[$pane]=0; PUB[$pane]=$raw; echo "$raw"
}

# --- poll loop --------------------------------------------------------------
while :; do
  # Exit cleanly if the tmux server is gone.
  panes=$(tmux list-panes -a -F '#{pane_id}	#{pane_tty}	#{pane_activity}' 2>/dev/null) || break

  for key in "${!ALIVE[@]}"; do unset "ALIVE[$key]"; done
  changed=0

  while IFS=$'\t' read -r pane tty activity; do
    [ -n "$pane" ] || continue
    ALIVE[$pane]=1

    # Content-change gate: if the pane is already idle and its activity timestamp
    # has not advanced, nothing new was drawn — reuse the published state and skip
    # the capture. Any non-idle state always re-scans (herdr's force-scan rule).
    # Guarded on a non-empty activity value: some servers don't populate
    # pane_activity (it needs monitor-activity), and an empty value must NOT be
    # treated as "unchanged" or an idle pane would never re-scan for a new turn.
    if [ "${PUB[$pane]:-}" = idle ] && [ -n "$activity" ] && [ "${ACT[$pane]:-}" = "$activity" ]; then
      logical=idle
    else
      raw=$(raw_state "$pane" "$tty")
      ACT[$pane]=$activity
      logical=$(apply_hysteresis "$pane" "$raw")
    fi

    styled=$(style_glyph "$logical")
    if [ "${WRITTEN[$pane]:-}" != "$styled" ]; then
      printf '%s' "$styled" > "$CACHE_DIR/${pane}.glyph"
      WRITTEN[$pane]=$styled
      changed=1
    fi
  done <<< "$panes"

  # Prune state + cache files for panes that no longer exist.
  for pane in "${!WRITTEN[@]}"; do
    if [ -z "${ALIVE[$pane]:-}" ]; then
      rm -f "$CACHE_DIR/${pane}.glyph" 2>/dev/null
      unset "WRITTEN[$pane]" "PUB[$pane]" "PEND[$pane]" "FIRST[$pane]" "ACT[$pane]"
      changed=1
    fi
  done

  # Nudge attached clients to redraw so a changed glyph shows up promptly, rather
  # than waiting for the next status-interval tick.
  if [ "$changed" = 1 ]; then
    while read -r client; do
      [ -n "$client" ] && tmux refresh-client -S -t "$client" 2>/dev/null
    done < <(tmux list-clients -F '#{client_name}' 2>/dev/null)
  fi

  sleep "$POLL_INTERVAL"
done

cleanup
