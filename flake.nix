{
  description = "dotfiles - standalone home-manager config for Linux";

  inputs = {
    # Pinned to the current stable NixOS release (26.05 "Yarara", 2026-05).
    # When the next stable ships, bump BOTH lines together to the new number
    # (e.g. nixos-26.11 / release-26.11) and run ./install.sh.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # herdr ships its own flake. Source it directly so we track herdr's own
    # releases (0.7.3+) instead of waiting for them to land in stable nixpkgs,
    # which lags herdr upstream. Uses its own pinned nixpkgs (no `follows`) so
    # its build is not forced onto our stable set.
    herdr-flake.url = "github:ogulcancelik/herdr";
  };

  outputs = { self, nixpkgs, home-manager, herdr-flake, ... }:
    let
      # Distro-agnostic: this is the CPU/OS pair, not a distribution.
      # It works the same on Ubuntu, Fedora, Arch, Debian, etc.
      # Use "aarch64-linux" on ARM machines (Raspberry Pi, ARM servers, WSL on ARM).
      system = "x86_64-linux";

      # Overlay: graft individual package fixes onto the stable set.
      # Everything not listed here still comes from stable nixpkgs.
      overlay = final: prev: {
        # herdr from its own flake (see the herdr-flake input above).
        herdr = herdr-flake.packages.${system}.herdr;
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # claude-code and friends are unfree
        overlays = [ overlay ];
      };
    in {
      # `home-manager switch --flake .#user` builds this.
      # The name here must match install.sh (FLAKE_HOST).
      homeConfigurations."user" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
