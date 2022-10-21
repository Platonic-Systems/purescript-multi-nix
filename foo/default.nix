{ self, ... }: {
  perSystem = { self', config, inputs', system, pkgs, ... }:
    let
      dependencies = with config.purs-nix.ps-pkgs; [
        matrices
      ];
      ps = config.purs-nix.purs {
        inherit dependencies;
        dir = ./.;
      };
    in
    {
      packages.foo = config.purs-nix.build {
        name = "foo";
        src.path = ./.;
        info = { inherit dependencies; };
      };
      packages.foo-js = ps.modules.Foo.bundle {
        main = false;
        esbuild = {
          format = "cjs";
        };
      };
    };
}
