{
  description = "Aseprite Package Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    pkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, pkgs-unstable, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (self: super: {
            gnupg = super.gnupg.overrideAttrs (oldAttrs: rec {
              configureFlags = (oldAttrs.configureFlags or []) ++ [
                "--with-pinentry-pgm=${super.pinentry_mac}/bin/pinentry-mac"
              ];
            });
          })
        ];
      };
      pkgsunstable = import pkgs-unstable { inherit system; };
    in rec {
      devShell = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          gnupg    # Dit is nu de aangepaste gnupg
          pinentry_mac
        ];

        shellHook = ''
          alias gm='git commit -S -m'
          alias gp='git push'
          alias ll='ls -la'
          export GPG_TTY=$(tty)
        '';
      };
    });
}