{ pkgs, inputs', ... }:

let
  npmlock2nix = import inputs'npmlock2nix { inherit pkgs; };
in
{
  name = "baz";
  srcs = [ "src" ];
  dependencies = [
    "console"
    "effect"
    "foo"
    "prelude"
  ];
  foreign.Main.node_modules = npmlock2nix.node_modules { src = ./.; } + "/node_modules";
}
