#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$DOTFILES_DIR/backup"
BACKUP_DIR=""
TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm.git"

MANAGED_FILES=(
  ".tmux.conf"
)

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Unsupported system: this installer is intended for Linux hosts." >&2
    return 1
  fi
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    return 1
  fi
}

ensure_backup_dir() {
  local candidate
  local counter
  local timestamp

  if [[ -n "$BACKUP_DIR" ]]; then
    return 0
  fi

  timestamp="$(date +%Y%m%d-%H%M%S)"
  candidate="$BACKUP_ROOT/$timestamp"
  counter=1

  while [[ -e "$candidate" ]]; do
    counter=$((counter + 1))
    candidate="$BACKUP_ROOT/$timestamp-$counter"
  done

  BACKUP_DIR="$candidate"
  mkdir -p "$BACKUP_DIR"
}

backup_existing_file() {
  local target="$1"
  local relative_path
  local backup_path

  ensure_backup_dir

  if [[ "$target" == "$HOME/"* ]]; then
    relative_path="${target#"$HOME/"}"
  else
    relative_path="$(basename "$target")"
  fi

  backup_path="$BACKUP_DIR/$relative_path"
  mkdir -p "$(dirname "$backup_path")"

  echo "Backing up existing file: $target -> $backup_path"
  mv "$target" "$backup_path"
}

link_file() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    echo "Missing source: $source" >&2
    return 1
  fi

  if [[ -L "$target" ]]; then
    local current_target
    current_target="$(readlink "$target")"

    if [[ "$current_target" == "$source" ]]; then
      echo "Already linked: $target -> $source"
      return 0
    fi

    echo "Replacing symlink: $target -> $current_target"
    rm "$target"
  elif [[ -e "$target" ]]; then
    backup_existing_file "$target"
  fi

  ln -s "$source" "$target"
  echo "Linked: $target -> $source"
}

install_dotfiles() {
  local file

  for file in "${MANAGED_FILES[@]}"; do
    link_file "$DOTFILES_DIR/$file" "$HOME/$file"
  done
}

install_tpm() {
  if [[ -d "$TPM_DIR/.git" ]]; then
    echo "TPM already installed: $TPM_DIR"
    return 0
  fi

  if [[ -e "$TPM_DIR" ]]; then
    echo "TPM path already exists, skipping clone: $TPM_DIR" >&2
    return 0
  fi

  require_command git

  mkdir -p "$(dirname "$TPM_DIR")"
  git clone "$TPM_REPO" "$TPM_DIR"
  echo "Installed TPM: $TPM_DIR"
}

main() {
  require_linux
  install_dotfiles
  install_tpm

  echo "Done."
}

main "$@"
