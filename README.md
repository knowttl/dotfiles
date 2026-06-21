# dotfiles

Personal configuration files.

## Contents

- `.tmux.conf` - tmux configuration with mouse support, vim-style pane movement, split bindings, larger history, and TPM plugin declarations.

## Install

Clone the repository and run the installer:

```sh
git clone <your-dotfiles-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer is intended for Linux hosts. It symlinks supported config files into the current user's home directory and installs TPM if it is not already present. If an existing non-symlink file is present, it is moved aside with a timestamped `.backup-*` suffix before the symlink is created.

## tmux plugins

This tmux config uses TPM. The installer clones TPM into `~/.tmux/plugins/tpm` when that path does not already exist. After installation, start tmux and press `prefix + I` to install the configured plugins.

## Notes

- Re-run `./install.sh` after adding more managed files.
- Do not commit secrets or machine-specific credentials to this repository.
- Keep local-only settings in separate untracked files when possible.
