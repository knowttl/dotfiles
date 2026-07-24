{
  description = "dotfiles - standalone home-manager config for Linux";

  inputs = {
    # Pinned to the current stable NixOS release (26.05 "Yarara", 2026-05).
    # When the next stable ships, bump BOTH lines together to the new number
    # (e.g. nixos-26.11 / release-26.11) and run ./install.sh.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      # Distro-agnostic: this is the CPU/OS pair, not a distribution.
      # It works the same on Ubuntu, Fedora, Arch, Debian, etc.
      # Use "aarch64-linux" on ARM machines (Raspberry Pi, ARM servers, WSL on ARM).
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # claude-code and friends are unfree
      };
    in {
      # `home-manager switch --flake .#default --impure` builds this.
      # The name here must match install.sh (FLAKE_HOST). User-agnostic:
      # home.nix reads USER/HOME from the environment (hence --impure).
      homeConfigurations."default" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
