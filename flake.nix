{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    purs-nix.url = "github:purs-nix/purs-nix";
    purs-nix.inputs.nixpkgs.follows = "nixpkgs";

    npmlock2nix = { url = "github:nix-community/npmlock2nix"; flake = false; };
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      systems = [ "x86_64-linux" "x86_64-darwin" ];
      imports = [
        ./nix/purs-nix/flake-module.nix
      ];
      perSystem = { self', config, system, pkgs, lib, ... }: {
        purs-nix = self.inputs.purs-nix {
          inherit system;
          overlays =
            [
              (self: super:
                let
                  build = config.purs-nix-multi.build-local-package;
                in
                {
                  foo = build self ./foo;
                  bar = build self ./bar;
                  zalgo = build self ./zalgo;
                })
            ];
        };
        packages = {
          inherit (config.purs-nix.ps-pkgs)
            foo bar zalgo;
          bar-js = self'.packages.bar.purs-nix-info-extra.ps.modules.Main.bundle {
            esbuild = {
              format = "cjs";
            };
          };
          zalgo-js = self'.packages.zalgo.purs-nix-info-extra.ps.modules.Main.bundle {
            esbuild = {
              format = "cjs";
            };
          };
        };
        apps = {
          bar = {
            type = "app";
            program = pkgs.writeShellApplication {
              name = "purescript-multi-bar";
              text = ''
                set -x
                ${lib.getExe pkgs.nodejs} ${self'.packages.bar-js}
              '';
            };

          };
          zalgo = {
            type = "app";
            program = pkgs.writeShellApplication {
              name = "purescript-multi-zalgo";
              text = ''
                set -x
                ${lib.getExe pkgs.nodejs} ${self'.packages.zalgo-js}
              '';
            };
          };
        };
        devShells.default = pkgs.mkShell {
          name = "purescript-multi-nix";
          buildInputs =
            let
              ps-tools = inputs.purs-nix.inputs.ps-tools.legacyPackages.${system};
            in
            [
              config.purs-nix.purescript
              config.purs-nix-multi.multi-command
              ps-tools.for-0_15.purescript-language-server
              ps-tools.for-0_15.purs-tidy
              pkgs.nixpkgs-fmt
            ];
        };
        formatter = pkgs.nixpkgs-fmt;
      };
    };
}
