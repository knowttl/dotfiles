#!/usr/bin/env bash
# tmux-agent-status.sh — per-window coding-agent status glyph for the tmux
# status bar.
#
# Purely READ-ONLY and DISPLAY-ONLY. It inspects one pane and prints exactly one
# (styled) glyph. It never renames windows, never sets tmux options, and never
# writes any state. That is what keeps it safe alongside firstmate: firstmate
# finds and steers its crew windows by their exact window_name ("fm-<id>") and by
# on-disk state files, and is completely oblivious to the status-bar text this
# feeds. Decorating the *displayed* window text does not change window_name, so
# nothing firstmate relies on is touched.
#
# Usage (from the catppuccin window text / window-status-format):
#   #(~/.config/tmux/tmux-agent-status.sh #{pane_id})
#
# Output is decided in this strict order:
#   TERM glyph — no coding-agent process is running in the pane (a plain shell,
#                a build, vim, an exited agent, an ssh session — anything that is
#                not an agent TUI).
#   BUSY glyph — an agent IS running AND its "busy" footer is on screen.
#   IDLE glyph — an agent IS running but no busy footer (quiet / your turn).

set -u

pane=${1:-}
[ -n "$pane" ] || exit 0

# --- glyphs (Nerd Font) -----------------------------------------------------
# Colored circles for agents; nf-cod-terminal for non-agent windows. The codicon
# is written as an ASCII \u escape (bash expands it at runtime) so its Private-
# Use-Area byte cannot be lost by tools/editors that mangle such glyphs.
busy_glyph=${TMUX_AGENT_GLYPH_BUSY:-●}
idle_glyph=${TMUX_AGENT_GLYPH_IDLE:-●}
term_glyph=${TMUX_AGENT_GLYPH_TERM:-$'\uEA85'}   # nf-cod-terminal (U+EA85)

# --- per-state colors (catppuccin mocha) ------------------------------------
# Foreground only, so the catppuccin segment background is preserved. reset_fg
# restores the window-text foreground after the glyph so the window name (#W)
# renders exactly as it normally would (mocha @thm_fg = #cdd6f4).
busy_color=${TMUX_AGENT_COLOR_BUSY:-#fab387}   # peach/orange = running
idle_color=${TMUX_AGENT_COLOR_IDLE:-#a6e3a1}   # green        = idle / your turn
term_color=${TMUX_AGENT_COLOR_TERM:-#9399b2}   # muted overlay = not an agent
reset_fg=${TMUX_AGENT_FG_RESET:-#cdd6f4}

emit() {  # <fg-color> <glyph>
  printf '#[fg=%s]%s#[fg=%s]' "$1" "$2" "$reset_fg"
}

# --- the three tuning points ------------------------------------------------
# Each default is set with a single-quoted assignment, NOT ${VAR:-default}: the
# latter's quote-removal strips regex backslashes (turning grok's "Ctrl\+c" into
# "Ctrl+c" and "Working\.\.\." into "Working...", silently breaking detection).
# A set environment variable still overrides each default.
#
# 1. Which processes count as a coding-agent TUI. Matched against each process's
#    FULL argv on the pane's tty. The leading (^|/) boundary is deliberate: it
#    matches the `claude` BINARY (".../bin/claude", "claude -p …") while
#    rejecting the ubiquitous `~/.claude/` CONFIG-DIR paths that appear in
#    unrelated command lines (they are always "/.claude", never "/claude"). The
#    trailing ([^[:alnum:]]|$) still matches packaged forms like
#    ".../claude-code/cli.js" while rejecting look-alikes such as "claudexyz".
agent_re=${TMUX_AGENT_PROC_RE:-}
[ -n "$agent_re" ] || agent_re='(^|/)(claude|codex|opencode|grok|pi|aider|cursor-agent)([^[:alnum:]]|$)'
# 2. The footer each agent shows ONLY while a turn is running. (claude/codex:
#    "esc to interrupt"; opencode: "esc interrupt"; pi: "Working..."; grok:
#    "Ctrl+c:cancel".) Extend this when a new agent is verified.
busy_re=${TMUX_AGENT_BUSY_RE:-}
[ -n "$busy_re" ] || busy_re='esc[[:space:]]+(to[[:space:]]+)?interrupt|Working\.\.\.|Ctrl\+c:cancel'
# 3. Full-line "busy" patterns, scanned over a slightly larger footer window.
#    Default: claude's background-agent wait line ("✻ Waiting for N background
#    agent(s) to finish"). While a backgrounded sub-agent runs, claude's main
#    thread is interactive and shows NO interrupt footer, so busy_re alone reads
#    it idle even though work is in flight. Handles any count and the singular/
#    plural ("[0-9]+ ... agents?") and an optional trailing UI hint that claude
#    may append with several agents (e.g. "… to finish (ctrl+o to expand)").
#    Anchored to a near-standalone status line — only a spinner/punctuation prefix
#    before "Waiting", and nothing but that optional hint after "to finish" — so
#    the same phrase appearing inside conversation/output text (which has real
#    words before it or trailing prose after it) does NOT count as busy.
busy_line_re=${TMUX_AGENT_BUSY_LINE_RE:-}
[ -n "$busy_line_re" ] || busy_line_re='^[[:space:]]*[^[:alnum:]]*Waiting for [0-9]+ background agents? to finish([[:space:]]*\([^)]*\))?[[:space:]]*$'

# --- 1. is a coding agent running in this pane? -----------------------------
# List every process on the pane's tty and match the signature. Scanning the tty
# (not just #{pane_current_command}) catches node/python-based agents whose
# command name is only the runtime, and catches an agent that has shelled out to
# run a tool, because the agent process is still attached to the pane's tty.
tty=$(tmux display-message -p -t "$pane" '#{pane_tty}' 2>/dev/null) || exit 0
[ -n "$tty" ] || { emit "$term_color" "$term_glyph"; exit 0; }

if ! ps -t "${tty#/dev/}" -o args= 2>/dev/null | grep -Eiq "$agent_re"; then
  emit "$term_color" "$term_glyph"
  exit 0
fi

# --- 2. agent present: busy or idle? ----------------------------------------
# Capture the pane once, drop blank lines, and treat it as busy on either:
#   (a) a busy FOOTER in the last 6 lines (busy_re) — the interrupt/working hint
#       shown on the bottom status bar while a turn is actively streaming; the
#       tight window stops a busy-looking string in scrollback from false-firing.
#   (b) a claude BACKGROUND-AGENT status line (busy_line_re) a few rows higher,
#       so it is scanned over a slightly larger, still footer-local window.
lines=$(tmux capture-pane -p -t "$pane" 2>/dev/null | grep -v '^[[:space:]]*$')
if printf '%s\n' "$lines" | tail -6 | grep -qiE "$busy_re" \
   || printf '%s\n' "$lines" | tail -12 | grep -qiE "$busy_line_re"; then
  emit "$busy_color" "$busy_glyph"
else
  emit "$idle_color" "$idle_glyph"
fi
