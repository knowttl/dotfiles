#!/usr/bin/env bash
# Refresh hand-pinned binary packages to their latest upstream versions and
# write the results into pins.json. These packages are pinned by version+hash
# instead of being flake inputs, so `nix flake update` cannot bump them - this
# script does. It runs automatically from `install.sh --update`, and is safe to
# run standalone.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PINS="$DIR/pins.json"

# nix store prefetch-file needs the nix-command experimental feature.
export NIX_CONFIG="experimental-features = nix-command flakes"

# Content hash for a URL. $1=url $2=hash-type (sha256|sha512)
prefetch() {
  nix store prefetch-file --json --hash-type "$2" "$1" | jq -r .hash
}

# Merge one package's version+hash into pins.json atomically. $1=name $2=ver $3=hash
write_pin() {
  local tmp
  tmp="$(mktemp)"
  jq --arg n "$1" --arg v "$2" --arg h "$3" \
    '.[$n] = {version: $v, hash: $h}' "$PINS" >"$tmp"
  mv "$tmp" "$PINS"
}

# codex: latest GitHub release of openai/codex (tag is rust-v<version>), sha256.
update_codex() {
  local version url hash
  version="$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest \
    | jq -r .tag_name | sed 's/^rust-v//')"
  url="https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz"
  hash="$(prefetch "$url" sha256)"
  write_pin codex "$version" "$hash"
  echo "==> codex -> $version"
}

# opencode: latest npm release of opencode-linux-x64-baseline, sha512.
update_opencode() {
  local version url hash
  version="$(curl -fsSL https://registry.npmjs.org/opencode-linux-x64-baseline/latest \
    | jq -r .version)"
  url="https://registry.npmjs.org/opencode-linux-x64-baseline/-/opencode-linux-x64-baseline-${version}.tgz"
  hash="$(prefetch "$url" sha512)"
  write_pin opencode "$version" "$hash"
  echo "==> opencode -> $version"
}

update_codex
update_opencode
