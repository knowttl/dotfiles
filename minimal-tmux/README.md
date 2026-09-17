# Minimal tmux config for servers

A self-contained, plugin-free tmux configuration for production servers where installing plugins or extra tooling is undesirable.
It uses only built-in tmux features: no TPM, no plugins, no external binaries, and no background daemons.

## Install

Run this one-liner on the server:

```bash
curl -fsSL https://raw.githubusercontent.com/knowttl/dotfiles/main/minimal-tmux/install.sh | bash
```

The installer backs up any existing `~/.tmux.conf` to `~/.tmux.conf.bak.<timestamp>`, writes the minimal config, and reloads it live if you are already inside a tmux session.

To inspect the installer before running it (recommended on machines you do not control):

```bash
curl -fsSL https://raw.githubusercontent.com/knowttl/dotfiles/main/minimal-tmux/install.sh | less
```

## What you get

- `M-a` secondary prefix (alongside the default `C-b`)
- vim-style pane navigation (`prefix h/j/k/l`) and alt-arrow pane resizing
- Window navigation: `prefix b`, and prefix-free `M-H` / `M-L`
- Splits that keep the current path (`prefix -`, `prefix \`, `prefix c`), `prefix x` to kill a pane
- `prefix r` to reload the config
- Mouse support and a top status bar with a mauve accent

The config is `tmux.conf` in this directory; it is fully declarative and runs no shell commands once installed.
