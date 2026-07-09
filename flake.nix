{
  description = "dotfiles - standalone home-manager config for Linux";

  inputs = {
    # Pinned to the current stable NixOS release (26.05 "Yarara", 2026-05).
    # When the next stable ships, bump BOTH lines together to the new number
    # (e.g. nixos-26.11 / release-26.11) and run ./install.sh.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Unstable is used ONLY to source packages that haven't landed in stable
    # yet (currently: herdr). The base system stays on stable nixpkgs above.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      # Distro-agnostic: this is the CPU/OS pair, not a distribution.
      # It works the same on Ubuntu, Fedora, Arch, Debian, etc.
      # Use "aarch64-linux" on ARM machines (Raspberry Pi, ARM servers, WSL on ARM).
      system = "x86_64-linux";

      # Overlay: graft individual package fixes onto the stable set.
      # Everything not listed here still comes from stable nixpkgs.
      overlay = final: prev: {
        inherit (import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        }) herdr;

        opencode = prev.stdenvNoCC.mkDerivation rec {
          pname = "opencode";
          version = "1.17.15";

          src = prev.fetchurl {
            url = "https://registry.npmjs.org/opencode-linux-x64-baseline/-/opencode-linux-x64-baseline-${version}.tgz";
            hash = "sha512-jUPpE5SqnzOpgu+s0IrivU/UK3l7JKZtSuEKpgtrcdntAqZ7W0LtiUsCIo18d8ryubg3HSnGdmLZwesKdtpOSA==";
          };

          nativeBuildInputs = [ prev.makeWrapper ];

          installPhase = ''
            runHook preInstall

            install -Dm755 bin/opencode $out/bin/.opencode-wrapped
            makeWrapper $out/bin/.opencode-wrapped $out/bin/opencode \
              --prefix PATH : ${prev.lib.makeBinPath [ prev.ripgrep ]}

            runHook postInstall
          '';
        };
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
