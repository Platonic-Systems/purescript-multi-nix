{ self, ... }: {
  perSystem = { self', config, inputs', system, pkgs, ... }:
    let
      dependencies = with config.purs-nix.ps-pkgs; [
        prelude
        effect
        console
        foo
      ];
      ps = config.purs-nix.purs {
        inherit dependencies;
        dir = ./.;
      };
    in
    {
      packages.bar = (config.purs-nix.build {
        name = "bar";
        src.path = ./.;
        info = { inherit dependencies; };
      }).overrideAttrs (config.purs-nix-multi.inject-info {
        inherit ps;
        src-globs = [ "bar/src/**/*.purs" ];
      });
      packages.bar-js = ps.modules.Main.bundle {
        esbuild = {
          format = "cjs";
        };
      };
    };
}
