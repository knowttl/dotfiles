#!/usr/bin/env bash
# Install a minimal, plugin-free tmux config on a server.
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/knowttl/dotfiles/main/minimal-tmux"
DEST="$HOME/.tmux.conf"

if [ -e "$DEST" ]; then
  backup="$DEST.bak.$(date +%Y%m%d%H%M%S)"
  cp "$DEST" "$backup"
  echo "Backed up existing config to $backup"
fi

curl -fsSL "$RAW_BASE/tmux.conf" -o "$DEST"
echo "Wrote minimal tmux config to $DEST"

if [ -n "${TMUX:-}" ]; then
  tmux source-file "$DEST" && echo "Reloaded live tmux session."
else
  echo "Start tmux to apply (or: tmux source-file $DEST)."
fi
