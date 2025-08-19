{
  description = "yo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.zig
            pkgs.freenect
            pkgs.pkg-config
            pkgs.usbutils

            pkgs.bashInteractive
            pkgs.ncurses
          ];

          shellHook = ''
            export SHELL=${pkgs.bashInteractive}/bin/bash
            export TERM=xterm-256color
            export INPUTRC=$HOME/.inputrc
          '';
        };
      });
}
