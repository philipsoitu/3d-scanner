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

        # freenect + udev rules
        freenect-with-udev = pkgs.freenect.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            mkdir -p $out/lib/udev/rules.d
            cat > $out/lib/udev/rules.d/99-kinect.rules <<'EOF'
            # Xbox NUI Motor
            SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02b0", MODE:="0666"

            # Xbox NUI Audio
            SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02ad", MODE:="0666"

            # Xbox NUI Camera
            SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02ae", MODE:="0666"

            # Xbox NUI Hub
            SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02c2", MODE:="0666"
            EOF
          '';
        });
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.zig
            freenect-with-udev
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
