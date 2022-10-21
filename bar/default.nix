{ self, ... }: {
  perSystem = { self', config, inputs', system, pkgs, ... }:
    let
      pkg = config.purs-nix-multi.build-local-package {
        name = "bar";
        root = ./.;
        dependencies = with config.purs-nix.ps-pkgs; [
          prelude
          effect
          console
          foo
        ];
        src-globs = [ "bar/src/**/*.purs" ];
      };
    in
    {
      packages.bar = pkg;
      packages.bar-js = pkg.purs-nix-info-extra.ps.modules.Main.bundle {
        esbuild = {
          format = "cjs";
        };
      };
    };
}
