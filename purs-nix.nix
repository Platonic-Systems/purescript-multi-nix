# A (provisional) flake-parts module for purs-nix
{ self, ... }: {
  perSystem = { config, self', inputs', system, pkgs, lib, ... }: {
    options = {
      purs-nix = lib.mkOption {
        type = lib.types.unspecified;
      };

      purs-nix-multi = lib.mkOption {
        description = "Multi-package project support for purs-nix";
        default = { };
        type = lib.types.submodule {
          options = {
            multi-command = lib.mkOption {
              type = lib.types.package;
              description = ''
                A purs-nix command for multi-package project.

                Specifically, running `purs-nix compile` is expected to compile
              '';
              default =
                let
                  isRemotePackage = p:
                    lib.hasAttr "repo" p.purs-nix-info
                    || lib.hasAttr "flake" p.purs-nix-info;

                  localPackages =
                    # Local packages in the package set.
                    #
                    # These packages exist locally in this project, and not being pulled
                    # from anywhere.
                    lib.filterAttrs (_: p: !isRemotePackage p) config.purs-nix.ps-pkgs;

                  allDependenciesOf = ps:
                    # Get the dependencies the given list of packages depends on, excluding
                    # those packages themselves.
                    lib.subtractLists ps
                      (lib.concatMap (p: p.purs-nix-info.dependencies) ps);

                  # HACK: purs-nix has no multi-pacakge support; so we string
                  # together 'dependencies' of local packages to create a top-level
                  # phantom one and create the purs-nix command for it. This is how
                  # pkgs.haskellPackges.shellFor funtion in nixpkgs works to create
                  # a Haskell development shell for multiple packages.
                  toplevel-ps =
                    config.purs-nix.purs {
                      dependencies = allDependenciesOf (lib.attrValues localPackages);
                    };

                  # HACK: Since we do not use the likes of cabal or spago, it is
                  # impossible to get relative src globs without explicitly
                  # having the developer specify them (in passthru; see further
                  # below).
                  localPackagesSrcGlobs =
                    lib.concatMap (p: p.purs-nix-info-extra.src-globs) (lib.attrValues localPackages);

                  toplevel-ps-command = toplevel-ps.command {
                    src-globs = lib.concatStringsSep " " localPackagesSrcGlobs;
                  };
                in
                toplevel-ps-command;
            };

            inject-info = lib.mkOption {
              type = lib.types.functionTo (lib.types.functionTo (lib.types.attrsOf lib.types.raw));
              description = ''
                Via passthru, inject purs-nix-info-extra which is like
                purs-nix-info but contains additional metadata necessary to be
                able to create purs-nix 'command' objects.
              '';
              default = attrs: old: {
                passthru = (old.passthru or { }) // {
                  purs-nix-info-extra = attrs;
                };
              };
            };
          };
        };
      };
    };
  };
}
