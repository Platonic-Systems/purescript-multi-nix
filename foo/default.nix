{ self, ... }: {
  perSystem = { self', config, inputs', system, pkgs, ... }:
    let
      pkg = config.purs-nix-multi.build-local-package {
        name = "foo";
        root = ./.;
        dependencies = with config.purs-nix.ps-pkgs; [
          matrices
        ];
        src-globs = [ "foo/src/**/*.purs" ];
      };
    in
    {
      packages.foo = pkg;
      packages.foo-js = pkg.purs-nix-info-extra.ps.modules.Foo.bundle {
        main = false;
        esbuild = {
          format = "cjs";
        };
      };
    };
}
