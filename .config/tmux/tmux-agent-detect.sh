#!/usr/bin/env bash
# tmux-agent-detect.sh — shared detection library for the per-window coding-agent
# status glyph. Sourced by both the reader (tmux-agent-status.sh) and the daemon
# (tmux-agent-statusd.sh). Nothing here mutates tmux state: it only reads a pane's
# tty process list and its captured screen text and classifies it.
#
# The design mirrors herdr's detection engine, translated to shell:
#   * classify_screen() is a PURE function of the captured text (state is a
#     function of the screen, exactly like herdr's manifest rule evaluation), so
#     it can be unit-tested from fixtures with no tmux running.
#   * Rules are checked in a fixed PRIORITY order (freeze > blocked > busy >
#     idle), so a real confirmation dialog always beats a busy hint that beats a
#     bare prompt. This is herdr's "highest-priority matching rule wins".
#   * Each rule is scoped to a purpose-built REGION (a bottom-of-screen slice),
#     not the whole pane, to keep scrollback text from false-firing.
#   * A "freeze" verdict marks an untrusted screen (transcript viewer / model
#     picker) — herdr's skip_state_update — telling the daemon to hold the last
#     real state instead of guessing.
#
# The hysteresis / debounce / startup-grace behaviors live in the daemon, since
# they need memory across polls; this library is deliberately stateless.

# --- glyphs (Nerd Font) -----------------------------------------------------
# Colored circles for agent states; nf-cod-terminal for non-agent windows. The
# codicon is an ASCII \u escape (bash expands it at runtime) so its Private-Use-
# Area byte cannot be lost by tools/editors that mangle such glyphs.
agent_busy_glyph=${TMUX_AGENT_GLYPH_BUSY:-●}
agent_idle_glyph=${TMUX_AGENT_GLYPH_IDLE:-●}
agent_blocked_glyph=${TMUX_AGENT_GLYPH_BLOCKED:-●}
agent_term_glyph=${TMUX_AGENT_GLYPH_TERM:-$''}   # nf-cod-terminal (U+EA85)

# --- per-state colors (catppuccin mocha) ------------------------------------
# Foreground only, so the catppuccin segment background is preserved. The reset
# restores the window-text foreground so the window name (#W) renders normally.
agent_busy_color=${TMUX_AGENT_COLOR_BUSY:-#fab387}     # peach  = running
agent_idle_color=${TMUX_AGENT_COLOR_IDLE:-#a6e3a1}     # green  = idle / your turn
agent_blocked_color=${TMUX_AGENT_COLOR_BLOCKED:-#f38ba8}  # red = blocked / needs you
agent_term_color=${TMUX_AGENT_COLOR_TERM:-#9399b2}     # muted  = not an agent
agent_reset_fg=${TMUX_AGENT_FG_RESET:-#cdd6f4}

# --- detection patterns -----------------------------------------------------
# Each default is set with the `[ -n "$x" ] || x='...'` idiom, NOT ${VAR:-default}:
# the latter's quote-removal strips regex backslashes (turning "Working\.\.\." into
# "Working..." and "Ctrl\+c" into "Ctrl+c"), silently breaking detection. A set
# environment variable still overrides each default.

# 1. Which processes count as a coding-agent TUI. Matched against each process's
#    FULL argv on the pane's tty. The leading (^|/) boundary matches the `claude`
#    BINARY (".../bin/claude", "claude -p …") while rejecting the ubiquitous
#    `~/.claude/` CONFIG-DIR paths (they are always "/.claude", never "/claude").
#    The trailing ([^[:alnum:]]|$) matches packaged forms like
#    ".../claude-code/cli.js" while rejecting look-alikes such as "claudexyz".
agent_re=${TMUX_AGENT_PROC_RE:-}
[ -n "$agent_re" ] || agent_re='(^|/)(claude|codex|opencode|grok|pi|aider|cursor-agent)([^[:alnum:]]|$)'

# 2. The footer each agent shows ONLY while a turn is running. (claude/codex:
#    "esc to interrupt"; opencode: "esc interrupt"; pi: "Working..."; grok:
#    "Ctrl+c:cancel".) Scanned over a tight bottom window.
busy_re=${TMUX_AGENT_BUSY_RE:-}
[ -n "$busy_re" ] || busy_re='esc[[:space:]]+(to[[:space:]]+)?interrupt|ctrl\+c[[:space:]]*(to[[:space:]]+)?(interrupt|cancel)|Working\.\.\.|Ctrl\+c:cancel|esc[[:space:]]+again[[:space:]]+to[[:space:]]+interrupt'

# 3. Full-line "busy" patterns scanned over a slightly larger footer window.
#    Default: claude's background-agent wait line ("✻ Waiting for N background
#    agent(s) to finish"). While a backgrounded sub-agent runs, claude's main
#    thread is interactive and shows NO interrupt footer, so busy_re alone reads
#    it idle even though work is in flight. Anchored to a near-standalone status
#    line so the same phrase inside conversation text does NOT count as busy.
busy_line_re=${TMUX_AGENT_BUSY_LINE_RE:-}
[ -n "$busy_line_re" ] || busy_line_re='^[[:space:]]*[^[:alnum:]]*Waiting for [0-9]+ background agents? to finish([[:space:]]*\([^)]*\))?[[:space:]]*$'

# 4. BLOCKED footer patterns — an agent that has STOPPED and is waiting on YOU
#    (permission prompt, yes/no confirmation, multi-choice menu). Highest state
#    priority: checked before busy, because a confirmation dialog can co-exist
#    with an "esc to cancel" hint that would otherwise read busy. Sourced from
#    herdr's per-agent manifests. These strong phrases are self-sufficient:
blocked_re=${TMUX_AGENT_BLOCKED_RE:-}
[ -n "$blocked_re" ] || blocked_re='do you want to proceed\?|do you want to allow|would you like to proceed\?|permission required|allow command\?|press enter to confirm|enter to submit answer|waiting for permission|review your answers|\[y/n\]|\(y/n\)|❯[[:space:]]*[0-9]\.'
# A numbered "yes" choice line AND a numbered "no" choice line (claude/codex/
# copilot render "❯ 1. Yes" / "2. No"). Required TOGETHER so a stray numbered
# list in prose can't false-fire.
blocked_yes_re=${TMUX_AGENT_BLOCKED_YES_RE:-}
[ -n "$blocked_yes_re" ] || blocked_yes_re='^[[:space:]]*[^[:alnum:]]{0,3}[[:space:]]*[123][.)][[:space:]]*yes\b'
blocked_no_re=${TMUX_AGENT_BLOCKED_NO_RE:-}
[ -n "$blocked_no_re" ] || blocked_no_re='^[[:space:]]*[^[:alnum:]]{0,3}[[:space:]]*[123][.)][[:space:]]*no\b'
# The generic select-dialog affordance pair: a confirm key AND a cancel key.
blocked_confirm_re=${TMUX_AGENT_BLOCKED_CONFIRM_RE:-}
[ -n "$blocked_confirm_re" ] || blocked_confirm_re='enter[[:space:]]+(to[[:space:]]+)?(select|confirm|submit|accept)'
blocked_cancel_re=${TMUX_AGENT_BLOCKED_CANCEL_RE:-}
[ -n "$blocked_cancel_re" ] || blocked_cancel_re='esc[[:space:]]+(to[[:space:]]+)?(cancel|dismiss)'

# 5. FREEZE patterns — untrusted screens (transcript viewer, model picker) that
#    look nothing like live agent state and must not overwrite it (herdr's
#    skip_state_update). Guarded below so a real confirmation dialog still wins.
freeze_re=${TMUX_AGENT_FREEZE_RE:-}
[ -n "$freeze_re" ] || freeze_re='showing detailed transcript|↑/↓ to scroll|pgup/pgdn to (scroll|page)|home/end to jump|select model|esc to edit prev|esc/← to edit prev'

# --- pure classifier --------------------------------------------------------
# Reads a raw pane capture on stdin, prints exactly one of: freeze blocked busy
# idle. No tmux access, no side effects — a pure function of the screen text.
classify_screen() {
  local text lines footer last6 last12
  text=$(cat)
  lines=$(printf '%s\n' "$text" | grep -v '^[[:space:]]*$')
  footer=$(printf '%s\n' "$lines" | tail -15)
  last6=$(printf '%s\n' "$lines" | tail -6)
  last12=$(printf '%s\n' "$lines" | tail -12)

  # priority 1 — FREEZE: an agent-owned viewer/picker. Reuse the prior state.
  # Guarded: a screen that is actually a confirmation dialog is NOT frozen.
  if printf '%s\n' "$footer" | grep -qiE "$freeze_re" \
     && ! printf '%s\n' "$footer" | grep -qiE 'do you want to proceed\?|enter[[:space:]]+to[[:space:]]+select'; then
    echo freeze; return
  fi

  # priority 2 — BLOCKED: stopped, waiting on a human response.
  if printf '%s\n' "$footer" | grep -qiE "$blocked_re" \
     || { printf '%s\n' "$footer" | grep -qiE "$blocked_yes_re" \
          && printf '%s\n' "$footer" | grep -qiE "$blocked_no_re"; } \
     || { printf '%s\n' "$footer" | grep -qiE "$blocked_confirm_re" \
          && printf '%s\n' "$footer" | grep -qiE "$blocked_cancel_re"; }; then
    echo blocked; return
  fi

  # priority 3 — BUSY: a turn is actively streaming.
  if printf '%s\n' "$last6" | grep -qiE "$busy_re" \
     || printf '%s\n' "$last12" | grep -qiE "$busy_line_re"; then
    echo busy; return
  fi

  # priority 4 — IDLE: default fallback for a known agent (herdr's idle default).
  echo idle
}

# --- pane -> raw state -------------------------------------------------------
# raw_state <pane_id> <tty>: prints term|freeze|blocked|busy|idle. `term` means
# no coding-agent process is on the pane's tty. Pass the tty in to avoid an extra
# tmux round-trip when the caller already has it (the daemon does).
raw_state() {
  local pane=$1 tty=$2
  [ -n "$tty" ] || { echo term; return; }
  if ! ps -t "${tty#/dev/}" -o args= 2>/dev/null | grep -Eiq "$agent_re"; then
    echo term; return
  fi
  tmux capture-pane -p -t "$pane" 2>/dev/null | classify_screen
}

# detect_pane_raw <pane_id>: convenience wrapper that fetches the tty itself.
detect_pane_raw() {
  local pane=$1 tty
  tty=$(tmux display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null) || { echo term; return; }
  raw_state "$pane" "$tty"
}

# --- display ----------------------------------------------------------------
# emit <fg-color> <glyph>: styled glyph that restores the window-text foreground.
emit() { printf '#[fg=%s]%s#[fg=%s]' "$1" "$2" "$agent_reset_fg"; }

# style_glyph <state>: map a logical state to its styled glyph string.
style_glyph() {
  case "$1" in
    blocked) emit "$agent_blocked_color" "$agent_blocked_glyph" ;;
    busy)    emit "$agent_busy_color" "$agent_busy_glyph" ;;
    idle)    emit "$agent_idle_color" "$agent_idle_glyph" ;;
    *)       emit "$agent_term_color" "$agent_term_glyph" ;;
  esac
}

# Shared runtime dir for the per-pane glyph cache the daemon publishes and the
# reader consumes. Namespaced and private — never touches window_name or any
# tmux option, so it stays safe alongside firstmate.
agent_status_cache_dir() {
  printf '%s/tmux-agent-status' "${TMUX_TMPDIR:-${XDG_RUNTIME_DIR:-/tmp}}"
}

# The directory this library actually lives in, following the symlink back into
# the repo. Both the reader and the daemon resolve their sibling files from here,
# so the tools work even when only SOME of the three scripts were linked into
# ~/.config/tmux (which is exactly the failure mode of forgetting to re-run
# install.sh after adding a managed file).
agent_lib_dir() {
  local self
  self="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
  dirname "$self"
}

# Make sure the daemon is running; (re)launch it if not. Called by the reader on
# every invocation, so it self-heals a daemon that never started or has died.
# Cheap on the happy path (a pidfile check); throttled to at most one launch
# attempt per THROTTLE seconds across all readers via a shared stamp file, and
# deduped by the daemon's own flock, so it can never stampede.
ensure_daemon() {
  local dir lockf pidf stamp daemon pid now age
  dir="$(agent_status_cache_dir)"
  lockf="$dir/.daemon.lock"
  pidf="$dir/.daemon.pid"
  stamp="$dir/.daemon.check"
  mkdir -p "$dir" 2>/dev/null || return 0

  # Alive check. Prefer the daemon's own flock as the source of truth: if we
  # cannot grab it non-blocking, a daemon holds it and is alive. fd 8 is opened
  # append (never truncating the lock) and released when the subshell exits.
  # This is robust even if the pidfile is missing or stale (e.g. an older daemon
  # build that predates the pidfile). Fall back to the pidfile only where flock
  # is unavailable.
  if command -v flock >/dev/null 2>&1; then
    if [ -e "$lockf" ] && ! ( flock -n 8 ) 8>>"$lockf" 2>/dev/null; then
      return 0
    fi
  elif [ -r "$pidf" ] && read -r pid < "$pidf" 2>/dev/null \
       && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  # Throttle: at most one launch attempt per 10s across all readers.
  if [ -e "$stamp" ]; then
    now="$(date +%s 2>/dev/null || echo 0)"
    age="$(stat -c %Y "$stamp" 2>/dev/null || echo 0)"
    [ "$((now - age))" -lt 10 ] && return 0
  fi
  : > "$stamp" 2>/dev/null

  daemon="$(agent_lib_dir)/tmux-agent-statusd.sh"
  [ -x "$daemon" ] || return 0
  nohup "$daemon" >/dev/null 2>&1 &
}
