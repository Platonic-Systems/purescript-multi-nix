# purescript-multi

Trying out multi-package PureScript project using purs-nix.

## Layout

This repository has two packages:

- ./foo
- TODO

## Building packages

### PureScript package 

A "PureScript package" is, alas, a mere copy of the .purs source files. To build the *foo* PureScript package:

``` sh
nix build .#foo
```

Note that if you are on M1, you must add `--option system x86_65-darwin` because of https://github.com/purs-nix/purs-nix/issues/17.

### JavaScript bundle

Unlike PureScript packages, a JavaScript bundle is probably more useful inasmuch as compilation actually happens as part of the build. The PureScript package, above, will succeed in building even if there is a syntax error in the source tree.

To build the *foo* JS bundle:

``` sh
nix build .#foo-js
```

This produces the compiled JavaScript at ./result.

TODO: How to evaluate this in node repl?

## Dev shell

TODO
