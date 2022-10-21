# A (provisional) flake-parts module for purs-nix
{ self, ... }: {
  perSystem = { config, self', inputs', system, pkgs, lib, ... }: {
    options = {
      purs-nix = lib.mkOption {
        type = lib.types.unspecified;
      };

      local-packages = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        description = ''
          Local packages in the package set.

          These packages exist locally in this project, and not being pulled
          from anywhere.
        '';
        default =
          let
            remotePackage = p:
              lib.hasAttr "repo" p.purs-nix-info
              || lib.hasAttr "flake" p.purs-nix-info;
          in
          lib.filterAttrs (_: p: !remotePackage p) config.purs-nix.ps-pkgs;
      };

      transitive-dependencies = lib.mkOption {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        description = ''
          Get the dependencies the given list of packages depends on, excluding
          those packages themselves.
        '';
        default = ps:
          lib.subtractLists ps
            (lib.concatMap (p: p.purs-nix-info.dependencies) ps);
      };
    };
  };
}
