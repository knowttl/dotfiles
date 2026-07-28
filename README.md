# dotfiles

Personal dotfiles for Linux, managed with [Nix](https://nixos.org) +
[home-manager](https://github.com/nix-community/home-manager).
One repo, one command, and any Linux machine ends up configured the same way.

Windows hosts (e.g. the wezterm side of a WSL setup) are still handled by the
PowerShell installer - see [Windows](#windows).

## What you get

Running the switch builds:

- Nix user packages (ripgrep, fd, fzf, jq, lazygit, Neovim, tmux, git, ranger)
- Tools installed outside Nix so they track upstream releases instead of
  nixpkgs: the coding agents claude-code / codex / opencode / pi via their native
  installers, and herdr as the prebuilt binary from its GitHub releases
- Neovim's toolchain deps from Nix (gcc, make, nodejs, unzip) so treesitter,
  telescope, and Mason's language servers have what they need. LSP servers and
  formatters themselves are still managed by Mason inside Neovim - see
  [Neovim](#neovim-toolchain)
- Shell (zsh, aliases, autosuggestions, syntax highlighting, starship prompt)
- Editor (Neovim config, based on kickstart.nvim, under `home/.config/nvim`)
- Terminal (WezTerm config)
- tmux (config + the agent-status daemon scripts)
- Agent config (`home/AGENTS.md`, symlinked to Claude, Codex, and opencode)
- Nerd Fonts (JetBrains Mono, Hack)

## Design notes

- **Distro-agnostic.** This is standalone home-manager, not NixOS and not
  nix-darwin. It runs on any Linux distribution (Ubuntu, Fedora, Arch, Debian,
  WSL, ...) without touching the system package manager. Nothing here calls
  `apt`/`dnf`/`pacman`.
- **Stable by default.** `flake.nix` pins nixpkgs and home-manager to the
  current stable NixOS release (`nixos-26.05` / `release-26.05`). To upgrade,
  bump both branch numbers together and run `./install.sh`.
- **Edit-in-place.** The real config files live under `home/`. `home.nix` uses
  `mkOutOfStoreSymlink` to point `~/.config/nvim`, `~/.config/wezterm`,
  `~/.config/tmux`, `~/.config/herdr`, and `~/.tmux.conf` straight at this repo,
  so editing a file here edits your live config with no rebuild. You only run
  `./install.sh` when you change something that isn't a symlinked file, like a
  package list or a shell setting.
- **One idempotent script.** There is a single `install.sh`. Run it to set a
  machine up, and run it again any time to apply changes. Every step is guarded
  (nix install, repo symlink, TPM clone, login shell) so re-running is a no-op
  where nothing changed - the same command works on a fresh box and on day 200.

## Setup and daily use (Linux)

From a bare clone:

```sh
git clone https://github.com/knowttl/dotfiles.git
cd dotfiles
```

Before the first run, open the config and change the values in
[Make it yours](#make-it-yours) (username and home path at minimum).
Then, now and every time after:

```sh
./install.sh
```

(There's also a `rebuild` shell alias that runs the same script.)

On a fresh machine `install.sh`, in order:

1. Installs [Determinate Nix](https://install.determinate.systems) if missing
   (distro-agnostic installer).
2. Symlinks this repo to `~/.dotfiles` (the `mkOutOfStoreSymlink` paths in
   `home.nix` resolve through here, so it must exist before the build).
3. Clones TPM (tmux plugin manager) into `~/.tmux/plugins/tpm` if missing.
4. Runs `home-manager switch` (from the flake on first run, via the installed
   CLI after that).
5. Best-effort sets the nix `zsh` as your login shell (`/etc/shells` + `chsh`)
   if it isn't already. Skipped gracefully if it can't; the manual command is
   printed.

On later runs the guarded steps are skipped and it just re-applies the config.
Open a new terminal after the first run so zsh and the new PATH take effect.

### Validate without applying

Once Nix is installed you can check the config builds without touching your
system:

```sh
nix flake check
nix build --impure .#homeConfigurations.default.activationPackage --dry-run
```

## Make it yours

- **Username and home path** are taken from `$USER` / `$HOME` at switch time
  (`home.nix` reads them via `builtins.getEnv`, which is why `install.sh`
  passes `--impure`).
  Nothing to edit for a different user or host.
- **Git identity** in `home.nix` (`knowttl` / `knowttl42@gmail.com`).
- **Agent policy** `home/AGENTS.md` started as the template author's personal
  instructions and is symlinked to Claude / Codex / opencode. Edit it to your
  own preferences.
- **CPU architecture** `system` in `flake.nix` - `x86_64-linux` by default;
  use `aarch64-linux` on ARM.

### About the coding-agent packages

`claude-code`, `codex`, and `opencode` are fast-moving and unfree
(`allowUnfree = true` is set in `flake.nix`). If a future stable release is
missing one of these attributes, the build fails on exactly that line - just
remove it from `home.packages` in `home.nix`, or pull only that tool from an
`nixpkgs-unstable` overlay while keeping everything else on stable.

### Neovim toolchain

The Neovim config is based on kickstart.nvim and keeps **Mason** to manage LSP
servers and formatters (pyright, lua_ls, clangd, stylua, ...) from inside the
editor. Nix's job is only to provide the tools those depend on, so Mason and the
plugins have a working environment:

- `gcc` + `gnumake` - treesitter compiles parsers on first launch; fzf-native
  builds with `make`
- `nodejs` - runtime for node-based servers Mason installs (e.g. pyright)
- `unzip` - Mason unpacks some release archives with it
- `ripgrep` + `fd` - telescope live-grep and file finding

Manage language servers with `:Mason` inside Neovim as usual. Note Mason
installs dynamically-linked prebuilt binaries, so it works on glibc distros
(Ubuntu, Fedora, Arch, ...) but not on NixOS - there you'd switch those servers
to Nix packages instead.

## Windows

For a WSL setup, wezterm runs on the Windows host and reads its config from the
Windows home directory. That side is installed with PowerShell:

```powershell
.\install.ps1
```

It symlinks the shared `home/.config/wezterm/wezterm.lua` (and the background
image and herdr config) into the Windows home dir, and skips Linux-only files
like `.tmux.conf`. Windows may require Developer Mode or an elevated shell for
symlinks; the installer falls back to hard links otherwise.

## Notes

- The first time you launch `nvim`, it bootstraps
  [lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from
  GitHub. That needs network access once; after that it's offline.
- After bootstrap, start tmux and press `prefix + I` to install the tmux
  plugins declared in `.tmux.conf` via TPM.
- Do not commit secrets or machine-specific credentials to this repository.
