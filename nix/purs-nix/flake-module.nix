# A (provisional) flake-parts module for purs-nix
{ self, ... }: {
  perSystem = { config, self', inputs', system, pkgs, lib, ... }: {
    options = {
      purs-nix = lib.mkOption {
        type = lib.types.unspecified;
      };

      purs-nix-multi = lib.mkOption {
        description = ''
          Multi-package project support for purs-nix

          See `build-local-package` and `multi-command`.
        '';
        type = lib.types.attrsOf lib.types.unspecified;
        default = import ./multi.nix {
          inherit self pkgs lib inputs';
          inherit (config) purs-nix;
        };
      };
    };
  };
}
