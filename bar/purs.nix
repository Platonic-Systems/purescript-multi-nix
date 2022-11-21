{ pkgs, ... }:

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
