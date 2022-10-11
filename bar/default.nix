{ self, ... }: {
  perSystem = { self', inputs', system, pkgs, ... }:
    let
      purs-nix = self.inputs.purs-nix { inherit system; };
      dependencies = with purs-nix.ps-pkgs; [
        prelude
        effect
        console
        self'.packages.foo
      ];
      ps = purs-nix.purs {
        inherit dependencies;
        dir = ./.;
      };
    in
    {
      packages.bar = purs-nix.build {
        name = "bar";
        src.path = ./.;
        info = { inherit dependencies; };
      };
      packages.bar-js = ps.modules.Main.bundle {
        esbuild = {
          format = "cjs";
        };
      };
    };
}
