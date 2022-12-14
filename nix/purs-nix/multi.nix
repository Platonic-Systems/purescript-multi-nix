# Temporary implementation of https://github.com/purs-nix/purs-nix/issues/36
#
# To be removed once purs-nix implements the spec.
#
# WARNING: As this file is more of a temporary prototype, hacks abound. This
# fine; when we properly implement this in purs-nix, the code there will be
# refactored/ simplified.
{ self, pkgs, lib, purs-nix, inputs }:

let
  isRemotePackage = p:
    lib.hasAttr "repo" p.purs-nix-info
    || lib.hasAttr "flake" p.purs-nix-info
    || (! lib.hasAttr "purs-nix-info-extra" p);

  # Partition a dependencies list into local and non-local dependencies
  partitionDependencies = deps: {
    non-local = lib.filter (p: isRemotePackage p) deps;
    local = lib.filter (p: !isRemotePackage p) deps;
  };

  allDependenciesOf = ps:
    # Get the dependencies the given list of packages depends on, excluding
    # those packages themselves.
    lib.subtractLists ps
      (lib.concatMap (p: p.purs-nix-info.dependencies) ps);

  # Flatten the dependency list to include all transitive deps recursively.
  #
  # [Package] -> [Package]
  getDependenciesRecursively = dependencies:
    (purs-nix.purs
      {
        inherit dependencies;
      }
    ).dependencies;

  npmlock2nix = import inputs.npmlock2nix {
    inherit pkgs;
  };
in
{
  # A purs-nix command for multi-package project.
  #
  # Specifically, running `purs-nix compile` is expected to compile
  multi-command =
    let

      localPackages =
        # Local packages in the package set.
        #
        # These packages exist locally in this project, and not being pulled
        # from anywhere.
        lib.filterAttrs (_: p: !isRemotePackage p) purs-nix.ps-pkgs;

      # HACK: purs-nix has no multi-pacakge support; so we string
      # together 'dependencies' of local packages to create a top-level
      # phantom one and create the purs-nix command for it. This is how
      # pkgs.haskellPackges.shellFor funtion in nixpkgs works to create
      # a Haskell development shell for multiple packages.
      toplevel-ps =
        purs-nix.purs {
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

      allCommands = { "." = toplevel-ps-command; } // localPackageCommands;

      # Wrapper script to do the top-level dance before delegating
      # to the actual purs-nix 'command' script.
      #
      # - Determine $PWD relative to project root
      # - Look up that key in `localPackageCommands` and run it.
      wrapper =
        let
          # Produce a BASH `case` block for the given localPackages key.
          caseBlockFor = path:
            let command = allCommands.${path};
            in
            ''
              ${path})
                set -x
                cd ${path}
                ${lib.getExe command} "$@"
                ;;
            '';
        in
        pkgs.writeShellApplication {
          name = "purs-nix";
          text = ''
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
            pwd_rel=$(realpath --relative-to="$tree_root" .)

            echo "|| ============================================================================"
            echo "|| purs-nix multi.nix prototype: https://github.com/purs-nix/purs-nix/issues/36"
            echo "|| Project root: $tree_root"
            echo "|| PWD: $(pwd)"
            echo "|| PWD, relative: $pwd_rel"
            cd "$tree_root"

            echo "|| Registered purs-nix commands:"
            echo -e "||  ${lib.concatStringsSep "\n||  " (lib.mapAttrsToList (n: v: "${n} => ${lib.getExe v} ") allCommands)}"
            echo "|| ============================================================================"

            echo
            echo "> Delegating to the appropriate purs-nix 'command' ..."
            case "$pwd_rel" in 
              ${
                builtins.foldl' (acc: path: acc + caseBlockFor path)
                  ""
                  (lib.attrNames allCommands)
              }
              *)
                echo "ERROR: Unable to find a purs-nix command for the current directory ($pwd_rel)" >&2
                exit 1
                ;;
            esac
          '';
        };
    in
    wrapper.overrideAttrs (oa: {
      meta.description = "purs-nix wrapper for monorepo; eg.: cd lib/foo && purs-nix test";
    });

  # Build a local PureScript package
  build-local-package = ps-pkgs: root:
    let
      # Arguments to pass to purs-nix's "build" function.
      meta = import "${root}/purs.nix" {
        inherit pkgs npmlock2nix;
      };
      dependencies = map (name: ps-pkgs.${ name}) meta.dependencies;

      allDamnDeps = getDependenciesRecursively psArgs.dependencies;
      allDamnDepsTest = getDependenciesRecursively psArgs.test-dependencies;

      localDependenciesSrcGlobs =
        lib.concatMap
          (p: map changeRelativityToHere p.purs-nix-info-extra.srcs)
          ((partitionDependencies allDamnDeps).local);
      # [String]
      # Eg:
      #  ["../../array/src" "../../pre/src"]
      localDependenciesSrcGlobsTest =
        lib.concatMap
          (p: map changeRelativityToHere p.purs-nix-info-extra.srcs)
          ((partitionDependencies allDamnDepsTest).local);

      # HACK: There is no 'test-srcs', only 'test' in purs-nix command.
      # We inject the necessary code to build the expected test globs.
      #
      # String
      localDependenciesSrcGlobsTestCodeInjection =
        let
          head = builtins.head localDependenciesSrcGlobsTest;
          tail = builtins.tail localDependenciesSrcGlobsTest;
        in
        if builtins.length localDependenciesSrcGlobsTest == 0 then
          "test"
        else
          ''${head}/**/*.purs" ${toString (map (d: ''"${d}/**/*.purs"'') tail)} "test'';


      psArgs = lib.filterAttrs (_: v: v != null) {
        inherit dependencies;
        dir = root;
        srcs = meta.srcs or [ "src" ];
        foreign = meta.foreign or null;
        test = meta.test or null;
        test-module = meta.test-module or null;
        test-dependencies = map (name: ps-pkgs.${name}) (meta.test-dependencies or [ ]);
      };
      psLocalArgs = psArgs // {
        # Exclude local dependencies (they are specified in 'srcs' latter)
        dependencies =
          (partitionDependencies allDamnDeps).non-local;
        test-dependencies =
          (partitionDependencies allDamnDepsTest).non-local;
        foreign =
          builtins.foldl'
            (acc: pkg:
              # NOTE: We assume that there is no overlap in transitive foreign deps.
              acc //
                (pkg.purs-nix-info.foreign or { })
            )
            (meta.foreign or { })
            (partitionDependencies allDamnDeps).local;
      };
      ps = purs-nix.purs psArgs;
      psLocal = purs-nix.purs psLocalArgs;
      buildInfo = lib.filterAttrs (_: v: v != null) {
        inherit dependencies;
        foreign = meta.foreign or null;
      };
      pkg = purs-nix.build {
        inherit (meta) name;
        src.path = root;
        info = buildInfo;
      };
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
      changeRelativityToHere = path: fsLib.changeRelativityTo path rootRelativeToProjectRoot;
      outputDir = changeRelativityToHere "output";
      passthruAttrs = {
        purs-nix-info-extra =
          let
            mySrcs = map (p: rootRelativeToProjectRoot + "/" + p) meta.srcs;
          in
          rec {
            inherit meta ps psLocal psArgs psLocalArgs rootRelativeToProjectRoot outputDir;
            commandArgs = {
              output = outputDir;
              # See also psLocal's dependencies pruning above.
              srcs = localDependenciesSrcGlobs ++ map changeRelativityToHere mySrcs;
              # HACK of HACKs
              test = localDependenciesSrcGlobsTestCodeInjection;
              bundle.module = meta.main-module or "Main";

            };
            # NOTE: This purs-nix command is valid inasmuch as it
            # launched from PWD being the base directory of this
            # package's purs.nix file.
            command = psLocal.command commandArgs;
            srcs = mySrcs;
          };
      };
    in
    pkg.overrideAttrs (oa: {
      passthru = (oa.passthru or { }) // passthruAttrs;
    });
}
