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

        # Cross pkgs for Raspberry Pi (32-bit ARM)
        pkgsRpi = import nixpkgs {
          system = "x86_64-linux";
          crossSystem = { config = "aarch64-unknown-linux-gnu"; };
        };
      in {
        # Native dev shell
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.zig_0_15
            freenect-with-udev
            pkgs.pkg-config
            pkgs.usbutils

            pkgs.imagemagick
            pkgs.meshlab
            pkgs.cloudcompare

            pkgs.bashInteractive
            pkgs.ncurses
          ];

          shellHook = ''
            export SHELL=${pkgs.bashInteractive}/bin/bash
            export TERM=xterm-256color
            export INPUTRC=$HOME/.inputrc
          '';
        };

        # Cross build for Raspberry Pi
        packages.rpi = pkgs.stdenv.mkDerivation {
          pname = "3d-scanner";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = [ pkgs.zig_0_15 ];
          buildInputs = [ pkgsRpi.freenect ];

          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-global-cache
            mkdir -p $ZIG_GLOBAL_CACHE_DIR

            export FREENECT_INCLUDE=${pkgsRpi.freenect}/include
            export FREENECT_LIB=${pkgsRpi.freenect}/lib

            zig build -Dtarget=aarch64-linux-gnu -Dcpu=cortex_a72 --global-cache-dir $ZIG_GLOBAL_CACHE_DIR
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/_3d_scanner $out/bin/
          '';
        };
      });
}
