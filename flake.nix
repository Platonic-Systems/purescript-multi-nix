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
          buildInputs =
            let
              local-pkgs = [ self'.packages.foo self'.packages.bar ];
              # HACK: purs-nix has no multi-pacakge support; so we string
              # together 'dependencies' of local packages to create a top-level
              # phantom one and create the purs-nix command for it. This is how
              # pkgs.haskellPackges.shellFor funtion in nixpkgs works to create
              # a Haskell development shell for multiple packages.
              toplevel-ps = config.purs-nix.purs {
                dependencies =
                  lib.subtractLists local-pkgs
                    (lib.concatMap
                      (pkg: pkg.purs-nix-info.dependencies)
                      local-pkgs);
              };
            in
            [
              config.purs-nix.purescript
              (toplevel-ps.command {
                src-globs = lib.concatStringsSep " " [
                  # TODO: DRY: How to get this from purs-nix metadata of each
                  # item in `local-pkgs`?  Currently we are hardcoding the globs
                  # here, but this is not general enough.
                  "foo/src/**/*.purs"
                  "bar/src/**/*.purs"
                ];
              })
            ];
        };
        formatter = pkgs.nixpkgs-fmt;
      };
    };
}
