# A (provisional) flake-parts module for purs-nix
{ self, ... }: {
  perSystem = { config, self', inputs', system, pkgs, lib, ... }: {
    options = {
      purs-nix = lib.mkOption {
        type = lib.types.unspecified;
      };
    };
  };
}
