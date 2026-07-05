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
  # Change these two lines for a different user/host. Everything else is
  # distro-agnostic and derives from homeDirectory.
  home.username = "user";
  home.homeDirectory = "/home/user";

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
    claude-code
    codex
    opencode
    herdr     # terminal agent multiplexer (from unstable overlay; see flake.nix)
    # fonts everything renders in (see wezterm.lua fallback list)
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  # ---- Shell ---------------------------------------------------------------
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      rebuild = "${dotfiles}/install.sh";
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "knowttl";
      email = "knowttl42@gmail.com";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
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
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.tmux.conf";

  # One agent policy, shared across the three agent CLIs. Edit home/AGENTS.md
  # (it's the template author's - make it yours) and all three pick it up.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";

  # Let home-manager manage itself so `home-manager` CLI is on PATH.
  programs.home-manager.enable = true;
}
