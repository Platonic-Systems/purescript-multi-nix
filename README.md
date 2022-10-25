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

To build the bar package

```sh
nix build .#bar
```

Note that if you are on M1, you must add `--option system x86_65-darwin` because of https://github.com/purs-nix/purs-nix/issues/17.

### JavaScript bundle

Unlike PureScript packages, a JavaScript bundle is probably more useful inasmuch as compilation actually happens as part of the build. The PureScript package, above, will succeed in building even if there is a syntax error in the source tree.

To build the *bar* JS bundle:

``` sh
nix build .#bar-js
```

This produces the compiled JavaScript at ./result.

### Running the ./bar application

Once the JS bundle (`.#bar-js`) of the application package "bar" is produced using `nix build .#bar-js`, we can run it directly using NodeJS:

``` sh-session
❯ node ./result
Nix, Nix
Nix, Nix
Nix, Nix
```

Alternatively: `nix run`.


## Dev shell

The dev shell is a **work-in-progress**. 

### Multi-package command

Since purs-nix itself **does not** support a multi-package `purs-nix` command yet, we create a ghost top-level package and then produce the `purs-nix` command for it. See `devShells.default` in flake.nix as well as the purs-nix.nix it uses. Ultimately, the goal is to upstream support for multi-package dev shell to purs-nix.

What works:

- [ ] `purs-nix compile`
    - [x] Builds the 'src' directory of each local package, generating `./output` at top-level.
- [ ] `purs-nix test`
    - [ ] Build tests for individual packages
    - [ ] Run those built tests (again, for individual packages)
- [ ] `purs-nix bundle` (same as above)
- [ ] `purs-nix run` (same as above)

### IDE support

Run `purs-nix compile` to compile your sources, producing an `./output` directory. This directory, in turn, will be used by the PureScript language server. This is tested to work with VSCode.
