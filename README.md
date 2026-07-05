# dotfiles

Personal configuration files.

## Contents

- `.tmux.conf` - tmux configuration with mouse support, vim-style pane movement, split bindings, larger history, and TPM plugin declarations.
- `.config/wezterm/wezterm.lua` - WezTerm configuration shared by Windows and Linux hosts, including the managed background image at `assets/images/seed-gundam.jpg`.
- `.config/herdr/config.toml` - [herdr](https://herdr.dev) configuration shared by Windows and Linux hosts, with tmux-style keybindings mapped to mirror `.tmux.conf` (vim pane movement, `-`/`\` splits, prefix `ctrl+b`, Catppuccin Mocha theme).

## Linux Install

Clone the repository and run the Linux installer:

```sh
git clone <your-dotfiles-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```

The Linux installer symlinks supported config files into the current user's home directory and installs TPM if it is not already present. It installs `.tmux.conf` and the shared WezTerm config.

## Windows Install

From PowerShell, run:

```powershell
.\install.ps1
```

The Windows installer symlinks Windows-supported config files into the current user's home directory. It installs the shared WezTerm config at `~/.config/wezterm/wezterm.lua` and skips Linux-only files such as `.tmux.conf`.

Windows may require Developer Mode or an elevated PowerShell session to create symlinks.
When symlinks are unavailable, the Windows installer falls back to file hard links.

## Installer behavior

Managed files are platform-scoped. Existing matching symlinks are left unchanged. Existing real files are moved into a timestamped directory under `backup/` before replacement.

## tmux plugins

This tmux config uses TPM. The installer clones TPM into `~/.tmux/plugins/tpm` when that path does not already exist. After installation, start tmux and press `prefix + I` to install the configured plugins.

## Notes

- Re-run the installer for your platform after adding more managed files.
- Do not commit secrets or machine-specific credentials to this repository.
- Keep local-only settings in separate untracked files when possible.
