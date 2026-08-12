{ config, pkgs, ... }:

let
  # The repo is symlinked to ~/.dotfiles by install.sh.
  # mkOutOfStoreSymlink paths below resolve through here, so editing a file
  # under home/ in this repo is editing your live config - no rebuild needed
  # for symlinked files.
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  # ---- Identity ------------------------------------------------------------
  # Taken from the environment so the same config works for any user on any
  # host. Requires evaluating with --impure (install.sh passes it). Everything
  # else is distro-agnostic and derives from homeDirectory.
  home.username = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # The release you first installed with. Never edit after first switch unless
  # a home-manager release note tells you to - it is NOT the same as the
  # nixpkgs branch and does not need bumping when you upgrade.
  home.stateVersion = "26.05";

  # ---- Packages ------------------------------------------------------------
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search (telescope live-grep)
    fd        # fast find (telescope)
    fzf       # fuzzy finder (tmux popups)
    jq        # json on the command line
    gh        # github cli (git credential helper, PRs)
    openssh   # ssh client for git remotes
    lazygit
    neovim
    tmux
    ranger    # file manager (bound to tmux prefix-f)

    # --- neovim toolchain deps ---
    # Nix provides only the tools nvim's plugins depend on. Mason still manages
    # the LSP servers/formatters themselves (downloaded at runtime); these are
    # the things Mason's binaries and the plugins need present on the system:
    #   telescope    -> ripgrep + fd (above)
    #   treesitter   -> a C compiler + make to build parsers
    #   fzf-native   -> make
    #   node LSPs    -> nodejs (e.g. pyright, ts_ls installed via Mason)
    gcc
    gnumake
    unzip     # Mason unpacks some release archives with unzip
    nodejs

    # --- coding agents ---
    # claude-code, codex and opencode are installed via their native installers
    # (see install.sh) so they self-update to the latest release; nixpkgs lags
    # too far behind.
    # fonts everything renders in (see wezterm.lua fallback list)
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";
  home.sessionVariables.PI_TELEMETRY = "0";
  # Native coding-agent installs live in ~/.local/bin. See install.sh.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # ---- Shell ---------------------------------------------------------------
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid

    # Both of these default to false in home-manager, and both are wrong when
    # many shells run at once (herdr keeps a shell per pane). With append off,
    # every exiting shell rewrites the whole history file from its own
    # in-memory list instead of appending, so a stale pane can drop lines other
    # panes already wrote. With extended off, that rewrite also strips the
    # timestamps SHARE_HISTORY needs to merge entries across shells correctly.
    history.append = true;
    history.extended = true;

    initContent = ''
      bindkey '^f' autosuggest-accept

      # zsh picks vi mode on its own because EDITOR contains "vi" (nvim). Keep
      # it, but teach it the keys it does not know by default.

      # ctrl+arrow. Without these the terminal's ^[[1;5C/D is unmatched, zsh
      # falls back to the bare ^[ (vi-cmd-mode) and reads the tail as vi
      # commands - the trailing C/D then kill to end of line.
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word

      # Backspace in insert mode. zsh's vi default (vi-backward-delete-char)
      # refuses to delete past the point where you entered insert mode, so
      # after moving in cmd mode and pressing i/a, backspace appears frozen.
      # backward-delete-char deletes freely, matching bash/readline vi-mode.
      bindkey -M viins '^?' backward-delete-char
      bindkey -M viins '^H' backward-delete-char

      # Quote/bracket text objects (di", ci', da(, yi{, ...). zsh ships these
      # functions but binds neither, to avoid claiming keys users may have
      # bound themselves. Word objects (iw/aw/ia) are bound by default already.
      autoload -Uz select-quoted select-bracketed
      zle -N select-quoted
      zle -N select-bracketed
      for km in viopp visual; do
        for c in {a,i}''${(s..)^:-\'\"\`}; do
          bindkey -M $km $c select-quoted
        done
        for c in {a,i}''${(s..)^:-'()[]{}<>bB'}; do
          bindkey -M $km $c select-bracketed
        done
      done

      # Load nvm so npm-global CLIs installed under nvm's node
      # (gh-axi, atelier-axi, ...) are on PATH in interactive shells.
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

      # Load conda if this host has it installed under ~. Sourcing conda.sh is
      # conda's own documented equivalent of `conda init`, so `conda activate`
      # works without ever running `conda init` - which matters because it
      # targets the read-only ~/.zshrc and gets wiped on every switch. The file
      # guard keeps this a no-op on hosts without conda, so the shared config
      # stays portable. Add new install paths to the list if needed.
      for conda_base in "$HOME/miniforge3" "$HOME/miniconda3" "$HOME/anaconda3"; do
        if [ -f "$conda_base/etc/profile.d/conda.sh" ]; then
          . "$conda_base/etc/profile.d/conda.sh"
          break
        fi
      done
      unset conda_base

      # Load optional host-specific settings without changing this shared file.
      if [[ -r "$HOME/.zshrc.local" ]]; then
        source "$HOME/.zshrc.local"
      fi
    '';
    shellAliases = {
      ".."     = "cd ..";
      add      = "git add .";
      push     = "git push";
      pull     = "git pull";
      m        = "git switch main";
      rebuild  = "${dotfiles}/install.sh";
      ls       = "ls --color=auto";
      ll       = "ls --color=auto -lh";
      la       = "ls --color=auto -lha";
      grep     = "grep --color=auto";
      diff     = "diff --color=auto";
    };
  };

  # Shell history in SQLite, written synchronously per command. Unlike the flat
  # ~/.zsh_history file it has no whole-file rewrite, so concurrent herdr panes
  # cannot clobber each other's entries. zsh keeps writing its own history too;
  # atuin is the searchable record on top of it.
  programs.atuin = {
    enable = true;   # enableZshIntegration defaults to true
    # Leave Up as plain zsh prefix search so autosuggestions stay predictable.
    # ctrl-r opens atuin.
    flags = [ "--disable-up-arrow" ];
    settings = {
      search_mode = "fuzzy";
      auto_sync = false;     # local only, no atuin account
      update_check = false;
    };
  };

  programs.dircolors = {
    enable = true;
    # GNU's default paints directories bold blue (01;34), which is hard to read
    # on the rose-pine-moon background. Override just directories and symlinks
    # to readable rose-pine tones (foam / iris) so ls matches the starship
    # prompt; every other entry stays at the module's mkDefault values.
    settings = {
      DIR  = "1;38;2;156;207;216"; # foam
      LINK = "1;38;2;196;167;231"; # iris
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name  = "knowttl";
        email = "knowttl42@gmail.com";
      };
      credential.helper = "!gh auth git-credential";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      palette = "rose_pine";
      palettes.rose_pine = {
        love   = "#f083a0";
        gold   = "#f6c177";
        rose   = "#f0b8b5";
        pine   = "#56b6d8";
        foam   = "#b4e4ed";
        iris   = "#d4b8f0";
        text   = "#e0def4";
        subtle = "#b8b5d0";
        muted  = "#7a7890";
      };
      directory = {
        format            = "[$path]($style) ";
        style             = "bold foam";
        truncate_to_repo  = false;
        truncation_length = 0;
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
        style  = "bold rose";
      };
      git_status = {
        format    = "[$all_status$ahead_behind]($style) ";
        style     = "bold gold";
        untracked = "[?](bold love)";
        modified  = "[~](bold gold)";
        staged    = "[+](bold pine)";
        deleted   = "[-](bold love)";
        ahead     = "[⇡$count](bold pine)";
        behind    = "[⇣$count](bold love)";
        diverged  = "[⇕](bold love)";
      };
      character = {
        success_symbol = "[❯](bold pine)";
        error_symbol   = "[❯](bold love)";
      };
      cmd_duration = {
        format = "[$duration]($style) ";
        style  = "subtle";
      };
    };
  };

  # ---- Edit-in-place symlinks ---------------------------------------------
  # The real files live under home/ in this repo. ~/.config just points at
  # them, so editor changes are live and never drift from the repo.
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/tmux".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/tmux";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".pi/agent/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/keybindings.json";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/extensions/terminal-status-title.js".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions/terminal-status-title.js";
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.tmux.conf";

  # One agent policy, shared across the three agent CLIs. Edit home/AGENTS.md
  # (it's the template author's - make it yours) and every agent entry point
  # picks it up.
  home.file."AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # Let home-manager manage itself so `home-manager` CLI is on PATH.
  programs.home-manager.enable = true;
  news.display = "silent";
}
