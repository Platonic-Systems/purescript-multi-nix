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
      ];
      perSystem = { self', config, system, pkgs, lib, ... }: {
        purs-nix = self.inputs.purs-nix {
          inherit system;
          overlays =
            [
              (self: super: {
                foo = config.purs-nix-multi.build-local-package {
                  name = "foo";
                  root = ./foo;
                  dependencies = with config.purs-nix.ps-pkgs; [
                    matrices
                  ];
                  src-globs = [ "foo/src/**/*.purs" ];
                };
                bar = config.purs-nix-multi.build-local-package {
                  name = "bar";
                  root = ./bar;
                  dependencies = with config.purs-nix.ps-pkgs; [
                    prelude
                    effect
                    console
                    foo
                  ];
                  src-globs = [ "bar/src/**/*.purs" ];
                };
              })
            ];
        };
        packages = {
          inherit (config.purs-nix.ps-pkgs)
            foo bar;
          bar-js = self'.packages.bar.purs-nix-info-extra.ps.modules.Main.bundle {
            esbuild = {
              format = "cjs";
            };
          };
          default = pkgs.writeShellApplication {
            name = "purescript-multi";
            text = ''
              set -x
              ${lib.getExe pkgs.nodejs} ${self'.packages.bar-js}
            '';
          };
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
