#!/usr/bin/env bash
# Single idempotent entry point for this dotfiles repo on Linux.
# Run it as many times as you like: first run bootstraps everything, later runs
# just re-apply changes. Every step below is guarded, so nothing is done twice.
#
# Distro-agnostic: works on Ubuntu, Fedora, Arch, Debian, WSL, etc. It never
# calls apt/dnf/pacman - everything user-facing comes through Nix.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FLAKE_HOST="user"   # must match flake.nix homeConfigurations.<name>
TPM_DIR="$HOME/.tmux/plugins/tpm"

# --- 1. Nix (Determinate) -------------------------------------------------
if command -v nix >/dev/null 2>&1; then
  echo "==> nix present"
else
  echo "==> installing Determinate Nix"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# --- 2. Repo symlink ------------------------------------------------------
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so this
# has to point here before the switch. ln -sfn is idempotent.
echo "==> linking repo to ~/.dotfiles"
ln -sfn "$DIR" ~/.dotfiles

# --- 3. TPM (tmux plugin manager) -----------------------------------------
if [ -d "$TPM_DIR/.git" ]; then
  echo "==> TPM present"
else
  echo "==> cloning TPM"
  git clone https://github.com/tmux-plugins/tpm.git "$TPM_DIR"
fi

# --- 4. Apply home-manager config -----------------------------------------
# Use the installed CLI when it exists; otherwise (first run) pull it from the
# flake. Either path produces the same result, so re-running is safe.
echo "==> applying home-manager config (#$FLAKE_HOST)"
# Enable flakes/nix-command via env so child nix processes (home-manager spawns
# its own) inherit it too - a CLI flag only reaches the outer process.
export NIX_CONFIG="experimental-features = nix-command flakes"
if command -v home-manager >/dev/null 2>&1; then
  home-manager switch -b backup --flake ~/.dotfiles#"$FLAKE_HOST"
else
  nix run github:nix-community/home-manager -- \
    switch -b backup --flake ~/.dotfiles#"$FLAKE_HOST"
fi

# --- 5. Login shell (best effort) -----------------------------------------
# Only acts if zsh isn't already the login shell. Needs sudo for /etc/shells;
# skips gracefully with a printed manual command if it can't.
ZSH_BIN="$HOME/.nix-profile/bin/zsh"
CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || echo "")"
if [ -x "$ZSH_BIN" ] && [ "$CURRENT_SHELL" != "$ZSH_BIN" ]; then
  echo "==> setting zsh as login shell"
  grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null \
    || echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null \
    || echo "    add '$ZSH_BIN' to /etc/shells by hand, then: chsh -s '$ZSH_BIN'"
  chsh -s "$ZSH_BIN" || echo "    run by hand: chsh -s '$ZSH_BIN'"
fi

echo "==> done. Open a new terminal for shell/PATH changes to take effect."
