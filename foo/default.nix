{ self, ... }: {
  perSystem = { self', inputs', system, pkgs, ... }:
    let
      purs-nix = self.inputs.purs-nix { inherit system; };
      dependencies = with purs-nix.ps-pkgs; [
        matrices
      ];
      ps = purs-nix.purs {
        inherit dependencies;
        dir = ./.;
      };

    in
    {
      packages.foo = purs-nix.build {
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
