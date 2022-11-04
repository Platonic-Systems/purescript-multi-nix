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
                    lib.concatMap (p: p.purs-nix-info-extra.srcs) (lib.attrValues localPackages);

                  toplevel-ps-command = toplevel-ps.command {
                    srcs = localPackagesSrcGlobs;
                  };
                in
                toplevel-ps-command;
            };

            build-local-package = lib.mkOption {
              type = lib.types.functionTo (lib.types.functionTo lib.types.package);
              description = ''
                Build a local PureScript package
              '';
              default = ps-pkgs: attrs@{ name, root, dependencies, srcs }:
                let
                  # Arguments to pass to purs-nix's "build" function.
                  dependenciesDrv = map (name: ps-pkgs.${name}) dependencies;
                  buildAttrs = {
                    inherit name;
                    src.path = root;
                    info = { dependencies = dependenciesDrv; };
                  };
                  # Arguments to pass to purs-nix's "purs" function.
                  psAttrs = {
                    dir = root;
                    dependencies = dependenciesDrv;
                  };
                  ps = config.purs-nix.purs psAttrs;
                  pkg = config.purs-nix.build buildAttrs;
                  passthruAttrs = {
                    purs-nix-info-extra = {
                      inherit ps srcs;
                    };
                  };
                in
                pkg.overrideAttrs (oa: {
                  passthru = (oa.passthru or { }) // passthruAttrs;
                });
            };
          };
        };
      };
    };
  };
}
