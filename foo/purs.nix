{ pkgs, npmlock2nix ? null, ... }:

{
  name = "foo";
  srcs = [ "src" ];
  dependencies = [
    "matrices"
  ];
}
