# purescript-multi-nix

A demo of a multi-package PureScript project (monorepo) nixified using [purs-nix](https://github.com/purs-nix/purs-nix).

## Layout

Like [haskell-multi-nix](https://github.com/srid/haskell-multi-nix), this repository has two packages:

- `./foo` -- a PureScript library.
- `./bar` -- a PureScript executable, that depends on ./foo

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

TODO: How to evaluate this (the library function) the NodeJS repl?

### Building the ./bar application

Using the instructions above on how to build the ./foo package, we can likewise build the ./bar application:

``` sh
nix build .#bar
```

The above is of course not very useful, so let us build the ./bar application JS bundle:

``` sh
nix build .#bar-js
```

Now we can run the result directly in the NodeJS evaluator!

``` sh-session
❯ node ./result
Nix, Nix
Nix, Nix
Nix, Nix
```

Alternatively: `nix run`.


## Dev shell

The dev shell is a **work-in-progress**. Since purs-nix itself *does not* support a multi-package `purs-nix` command yet, we create a ghost top-level package and then produce the `purs-nix` command for it. See `devShells.default` in flake.nix.

### IDE support

Run the following to compile your sources, producing an `./output` directory:
This directory, in turn, will be used by the PureScript language server. This is tested to work with VSCode.
