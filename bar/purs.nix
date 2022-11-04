{ pkgs, npmlock2nix ? null, ... }:

{
  name = "bar";
  srcs = [ "src" ];
  dependencies = [
    "prelude"
    "effect"
    "console"
    "foo"
  ];
}
