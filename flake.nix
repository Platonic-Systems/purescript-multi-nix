{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    purs-nix.url = "github:purs-nix/purs-nix";
    purs-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      systems = [ "x86_64-linux" "x86_64-darwin" ];
      imports = [
        ./purs-nix.nix
        ./foo
        ./bar
      ];
      perSystem = { self', config, system, pkgs, lib, ... }: {
        purs-nix = self.inputs.purs-nix {
          inherit system;
          overlays =
            [
              (self: super: {
                inherit (self'.packages)
                  foo bar;
              })
            ];
        };
        packages.default = pkgs.writeShellApplication {
          name = "purescript-multi";
          text = ''
            set -x
            ${lib.getExe pkgs.nodejs} ${self'.packages.bar-js}
          '';
        };
        devShells.default = pkgs.mkShell {
          name = "purescript-multi-nix";
          buildInputs = [
            config.purs-nix.purescript
            config.purs-nix-multi.multi-command
            pkgs.nixpkgs-fmt
          ];
        };
        formatter = pkgs.nixpkgs-fmt;
      };
    };
}
