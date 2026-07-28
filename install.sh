#!/usr/bin/env bash
# Single idempotent entry point for this dotfiles repo on Linux.
# Run it as many times as you like: first run bootstraps everything, later runs
# just re-apply changes. Every step below is guarded, so nothing is done twice.
#
# Distro-agnostic: works on Ubuntu, Fedora, Arch, Debian, WSL, etc. It never
# calls apt/dnf/pacman - everything user-facing comes through Nix.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
FLAKE_HOST="default"   # must match flake.nix homeConfigurations.<name>
TPM_DIR="$HOME/.tmux/plugins/tpm"
ZSH_LOCAL="$HOME/.zshrc.local"

# --- Arguments ------------------------------------------------------------
# --update / -u bumps every pinned flake input to its newest version before
# applying, so the switch below installs the latest packages. A normal run
# checks for newer inputs and reports when --update is worth running.
UPDATE=0
FLAKE_LOCK_WAS_DIRTY=0
for arg in "$@"; do
  case "$arg" in
    -u|--update) UPDATE=1 ;;
    -h|--help)
      echo "usage: install.sh [--update]"
      echo "  --update, -u   update all packages to their newest versions"
      exit 0 ;;
    *)
      echo "unknown argument: $arg" >&2
      echo "usage: install.sh [--update]" >&2
      exit 1 ;;
  esac
done

if ! git -C "$DIR" diff --quiet -- flake.lock \
  || ! git -C "$DIR" diff --cached --quiet -- flake.lock; then
  FLAKE_LOCK_WAS_DIRTY=1
fi

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
  # GIT_TERMINAL_PROMPT=0 fails fast instead of prompting for credentials.
  GIT_TERMINAL_PROMPT=0 git clone https://github.com/tmux-plugins/tpm.git "$TPM_DIR"
fi

# Create a host-local zsh override file without replacing existing settings.
if [ -e "$ZSH_LOCAL" ] || [ -L "$ZSH_LOCAL" ]; then
  echo "==> zsh local config present"
else
  echo "==> creating $ZSH_LOCAL"
  printf '%s\n' \
    '# Host-specific zsh settings.' \
    '# This file is loaded after the shared Home Manager configuration.' \
    > "$ZSH_LOCAL"
  chmod 600 "$ZSH_LOCAL"
fi

# --- 4. Apply home-manager config -----------------------------------------
# Use the installed CLI when it exists; otherwise (first run) pull it from the
# flake. Either path produces the same result, so re-running is safe.
echo "==> applying home-manager config (#$FLAKE_HOST)"
# Enable flakes/nix-command via env so child nix processes (home-manager spawns
# its own) inherit it too - a CLI flag only reaches the outer process.
export NIX_CONFIG="experimental-features = nix-command flakes"

# Authenticate Nix's GitHub API calls when gh is logged in, lifting the
# 60/hour anonymous rate limit (flake inputs resolve via api.github.com).
# Skips silently on hosts where gh is absent or not yet authenticated.
if token=$(gh auth token 2>/dev/null); then
  NIX_CONFIG="$NIX_CONFIG
access-tokens = github.com=$token"
fi

check_flake_updates() {
  local check_dir check_lock
  check_dir="$(mktemp -d)"
  check_lock="$check_dir/flake.lock"

  if nix flake update --flake "$DIR" --output-lock-file "$check_lock" \
      >"$check_dir/update.log" 2>&1; then
    if cmp -s "$DIR/flake.lock" "$check_lock"; then
      echo "==> flake inputs are up to date"
    else
      echo "==> newer flake inputs are available"
      echo "    run ./install.sh --update to refresh them"
    fi
  else
    echo "==> could not check for newer flake inputs; continuing" >&2
  fi

  rm -rf "$check_dir"
}

# With --update, refresh flake.lock first so the switch pulls newest packages.
if [ "$UPDATE" -eq 1 ]; then
  echo "==> updating flake inputs to newest versions"
  nix flake update --flake "$DIR"
else
  check_flake_updates
fi
# --impure lets home.nix read USER/HOME from the environment, so the same
# config applies for any user on any host.
if command -v home-manager >/dev/null 2>&1; then
  home-manager switch -b backup --impure --flake ~/.dotfiles#"$FLAKE_HOST"
else
  nix run github:nix-community/home-manager -- \
    switch -b backup --impure --flake ~/.dotfiles#"$FLAKE_HOST"
fi

# --- 5. Coding agents (native installers) ---------------------------------
# Installed outside Nix so each tool's built-in auto-updater can keep it on the
# latest release; nixpkgs lags too far behind. The installers are idempotent
# and upgrade in place, so re-running just refreshes to newest.
echo "==> installing/updating Claude Code (native installer)"
curl -fsSL https://claude.ai/install.sh | bash
echo "==> installing/updating Codex (native installer)"
# CODEX_NON_INTERACTIVE answers "no" to the installer's /dev/tty prompts
# ("Start Codex now?"), which would otherwise hang the script mid-install.
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
echo "==> installing/updating opencode (native installer)"
curl -fsSL https://opencode.ai/install | bash
echo "==> installing/updating Pi (native installer)"
# Pi's installer uses /dev/tty for its action menu. A new session has no
# controlling terminal, so it automatically installs or updates without a prompt.
export PI_TELEMETRY=0
setsid --wait sh -c 'curl -fsSL https://pi.dev/install.sh | sh'
export PATH="$HOME/.local/bin:$PATH"

echo "==> installing/updating no-mistakes"
if command -v no-mistakes >/dev/null 2>&1; then
  no_mistakes_update_output=""
  if ! no_mistakes_update_output="$(no-mistakes update --yes 2>&1)"; then
    printf '%s\n' "$no_mistakes_update_output"
    if ! printf '%s\n' "$no_mistakes_update_output" \
      | grep -q 'active pipeline runs'; then
      exit 1
    fi
    echo "    daemon restart deferred while a pipeline is active"
  else
    printf '%s\n' "$no_mistakes_update_output"
  fi
else
  curl -fsSL https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.sh | sh
fi
echo "==> installing/updating treehouse"
curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh
echo "==> installing/updating gh-axi"
npm install --global gh-axi@latest
echo "==> installing/updating no-mistakes and gh-axi skills"
# Keep the canonical global skills in ~/.agents/skills and expose them only to
# Claude Code through ~/.claude/skills. Codex reads the shared global store.
npx --yes skills add kunchenguid/no-mistakes \
  --skill no-mistakes --global --agent claude-code --yes
npx --yes skills add kunchenguid/gh-axi \
  --skill gh-axi --global --agent claude-code --yes

echo "==> installing/updating Pi packages"
PI_PACKAGES=(
  npm:@tintinweb/pi-subagents
  npm:pi-web-access
  npm:@ff-labs/pi-fff
  npm:pi-stop
  npm:pi-effort
  npm:pi-patty-bg-tasks
  npm:pi-mcp-adapter
  npm:@juicesharp/rpiv-ask-user-question
)

for package in "${PI_PACKAGES[@]}"; do
  pi install "$package"
done

is_managed_pi_package() {
  local package
  for package in "${PI_PACKAGES[@]}"; do
    [[ "$package" == "$1" ]] && return 0
  done
  return 1
}

while read -r package; do
  [[ -z "$package" ]] && continue
  if ! is_managed_pi_package "$package"; then
    echo "==> removing unmanaged Pi package $package"
    pi remove "$package"
  fi
done < <(pi list | sed -nE 's/^  ([^[:space:]]+)$/\1/p')

# Keep the subagent list and background-agent widget visible by default.
node - "$HOME/.pi/agent/subagents.json" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const settingsPath = process.argv[2];
let settings = {};

try {
  settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}

settings.fleetView = true;
settings.widgetMode = "background";
fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
fs.writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);
NODE

# herdr has no installer script, but its CI publishes a prebuilt binary per
# release - downloading it beats the minutes-long Rust build its flake costs.
# releases/latest/download is a plain redirect, not the rate-limited API.
# Download to a temp name then mv so a running herdr is swapped atomically.
echo "==> installing/updating herdr (prebuilt release binary)"
mkdir -p "$HOME/.local/bin"
HERDR_VERSION_BEFORE="$("$HOME/.local/bin/herdr" --version 2>/dev/null || echo "")"
curl -fsSL -o "$HOME/.local/bin/herdr.tmp" \
  "https://github.com/ogulcancelik/herdr/releases/latest/download/herdr-linux-$(uname -m)"
chmod +x "$HOME/.local/bin/herdr.tmp"
mv "$HOME/.local/bin/herdr.tmp" "$HOME/.local/bin/herdr"

# Install integrations for the agents managed by this repository. These add
# native lifecycle/session reporting and must run after the herdr binary and
# agent config directories are available.
echo "==> installing herdr integrations"
for integration in pi claude codex opencode; do
  herdr integration install "$integration"
done

# A running server keeps serving the old binary's protocol, so every CLI call
# from the new one fails until it is restarted. The swap is what creates the
# skew, so say so here - silently upgrading under a live server leaves the
# fzf keybindings (prefix+a / prefix+s) failing with no visible cause.
HERDR_VERSION_AFTER="$("$HOME/.local/bin/herdr" --version 2>/dev/null || echo "")"
if [ -n "$HERDR_VERSION_BEFORE" ] \
  && [ "$HERDR_VERSION_BEFORE" != "$HERDR_VERSION_AFTER" ] \
  && pgrep -f 'herdr server' >/dev/null 2>&1; then
  echo "    upgraded $HERDR_VERSION_BEFORE -> $HERDR_VERSION_AFTER with a server running."
  echo "    restart herdr to pick it up (this exits every pane process):"
  echo "      HERDR_SOCKET_PATH=\"\$HOME/.config/herdr/herdr.sock\" herdr server stop"
fi

# --- 6. Login shell (best effort) -----------------------------------------
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

publish_flake_update() {
  [ "$UPDATE" -eq 1 ] || return 0

  if [ "$FLAKE_LOCK_WAS_DIRTY" -eq 1 ]; then
    echo "==> flake.lock had changes before the update; skipping automatic commit/push"
    return 0
  fi

  if git -C "$DIR" diff --quiet -- flake.lock \
    && git -C "$DIR" diff --cached --quiet -- flake.lock; then
    echo "==> flake.lock did not change; nothing to commit"
    return 0
  fi

  if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "==> non-interactive update; skipping automatic commit/push"
    return 0
  fi

  printf 'Commit and push the updated flake.lock? [y/N] '
  read -r answer
  case "$answer" in
    y|Y|yes|Yes|YES)
      git -C "$DIR" add flake.lock
      git -C "$DIR" commit --only flake.lock -m "Update flake inputs"
      git -C "$DIR" push
      echo "==> flake.lock committed and pushed"
      ;;
    *)
      echo "==> leaving flake.lock uncommitted"
      ;;
  esac
}

publish_flake_update

echo "==> done. Open a new terminal for shell/PATH changes to take effect."
