{ pkgs, ... }:

{
  name = "foo";
  srcs = [ "src" ];
  dependencies = [
    "matrices"
  ];
}
