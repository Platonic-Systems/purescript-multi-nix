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

                  # Attrset of purs-nix commands indexed by relative path to package root.
                  #
                  # { "foo" = <ps.command for foo>; ... }
                  localPackageCommands =
                    let
                      localPackagesByPath =
                        lib.groupBy
                          (p: p.passthru.purs-nix-info-extra.rootRelativeToProjectRoot)
                          (lib.attrValues localPackages);
                    in
                    lib.mapAttrs (_: p: (builtins.head p).passthru.purs-nix-info-extra.command) localPackagesByPath;

                  toplevel-ps-command = toplevel-ps.command {
                    srcs = localPackagesSrcGlobs;
                    output = "output";
                  };

                  allCommands = localPackageCommands // { "." = toplevel-ps-command; };

                  # Wrapper script to do the top-level dance before delegating
                  # to the actual purs-nix 'command' script.
                  #
                  # - Determine $PWD relative to project root
                  # - Look up that key in `localPackageCommands` and run it.
                  wrapper =
                    let
                      # Produce a BASH `case` block for the given localPackages key.
                      caseBlockFor = path:
                        ''
                          ${path})
                            set -x
                            cd ${path}
                            ${lib.getExe localPackages.${path}.passthru.purs-nix-info-extra.command} $*
                            ;;
                        '';
                    in
                    pkgs.writeShellScriptBin "purs-nix" ''
                      #!${pkgs.runtimeShell}
                      set -euo pipefail

                      find_up() {
                        ancestors=()
                        while true; do
                          if [[ -f $1 ]]; then
                            echo "$PWD"
                            exit 0
                          fi
                          ancestors+=("$PWD")
                          if [[ $PWD == / ]] || [[ $PWD == // ]]; then
                            echo "ERROR: Unable to locate the projectRootFile ($1) in any of: ''${ancestors[*]@Q}" >&2
                            exit 1
                          fi
                          cd ..
                        done
                      }

                      # TODO: make configurable
                      tree_root=$(find_up "flake.nix")
                      pwd_rel=$(realpath --relative-to=$tree_root .)

                      echo "> purs-nix metadata gathered"
                      echo "Project root: $tree_root"
                      echo "PWD: `pwd`"
                      echo "PWD, relative: $pwd_rel"
                      cd $tree_root

                      echo "Registered purs-nix commands:"
                      echo "  ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${n} => ${lib.getExe v} ") allCommands)}"
                      echo
                      echo "> Delegating to the appropriate purs-nix 'command' ..."
                      case "$pwd_rel" in 
                        ${
                          builtins.foldl' (acc: path: acc + caseBlockFor path)
                            ""
                            (lib.attrNames localPackageCommands)
                        }
                        *)
                          echo "ERROR: Unable to find a purs-nix command for the current directory ($pwd_rel)" >&2
                          exit 1
                          ;;
                      esac
                      # ${lib.getExe toplevel-ps-command} $*
                    '';
                in
                wrapper;
            };

            build-local-package = lib.mkOption {
              type = lib.types.functionTo (lib.types.functionTo lib.types.package);
              description = ''
                Build a local PureScript package
              '';
              default = ps-pkgs: root:
                let
                  # Arguments to pass to purs-nix's "build" function.
                  meta = import "${root}/purs.nix" { inherit pkgs; };
                  dependenciesDrv = map (name: ps-pkgs.${name}) meta.dependencies;
                  buildAttrs = {
                    inherit (meta) name;
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
                  fsLib = {
                    # Make the given path (`path`) relative to the `parent` path.
                    mkRelative = parent: path:
                      let
                        parent' = builtins.toString self;
                        path' = builtins.toString path;
                      in
                      if parent' == path' then "." else lib.removePrefix (parent' + "/") path';
                    # Given a relative path from root (`path`), construct the
                    # same but as being relative to `baseRel` (also relative to
                    # root) instead.
                    changeRelativityTo = path: baseRel:
                      let
                        # The number of directories to go back.
                        n =
                          if baseRel == "."
                          then 0
                          else lib.length (lib.splitString "/" baseRel);
                      in
                      builtins.foldl' (a: _: "../" + a) "" (lib.range 1 n) + path;
                  };
                  rootRelativeToProjectRoot = fsLib.mkRelative self root;
                  outputDir = fsLib.changeRelativityTo "output" rootRelativeToProjectRoot;
                  passthruAttrs = {
                    purs-nix-info-extra = {
                      inherit ps rootRelativeToProjectRoot outputDir;
                      # NOTE: This purs-nix command is valid inasmuch as it
                      # launched from PWD being the base directory of this
                      # package's purs.nix file.
                      command = ps.command { output = outputDir; };
                      srcs = map (p: rootRelativeToProjectRoot + "/" + p) meta.srcs;
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








