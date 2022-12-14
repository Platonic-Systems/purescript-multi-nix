{ pkgs, npmlock2nix, ... }:

{
  name = "zalgo";
  srcs = [ "src" ];
  dependencies = [
    "console"
    "effect"
    "foo"
    "prelude"
  ];
  foreign.Main = {
    type = "npm";
    path = ./.;
  };
}
