# purescript-multi-nix

A demo of a multi-package PureScript project (monorepo) nixified using [purs-nix](https://github.com/purs-nix/purs-nix).

## Layout

Like [haskell-multi-nix](https://github.com/srid/haskell-multi-nix), this repository has two packages:

- `./foo`: a PureScript library.
- `./bar`: a PureScript executable, depends on `./foo`

## Building packages

### PureScript package 

A "PureScript package" is, alas, a mere copy of the `.purs` source files. To build the *foo* PureScript package:

``` sh-session
❯ nix build .#foo
```

To build the *bar* package:

``` sh-session
❯ nix build .#bar
```

NOTE: if you are on a Apple silicon processor (such as M1, M2, etc.), you will need to add `--option system x86_64-darwin` and run binaries through [Rosetta 2](https://en.wikipedia.org/wiki/Rosetta_2_(software))’s x86 translator until native ARM-compatible binaries are built upstream (see: https://github.com/purs-nix/purs-nix/issues/17).

### JavaScript bundle

Unlike PureScript packages, a JavaScript bundle is probably more useful inasmuch as compilation actually happens as part of the build. The PureScript package, above, will succeed in building even if there is a syntax error in the source tree.

To build the *bar* JS bundle:

``` sh-session
❯ nix build .#bar-js
```

This produces the compiled JavaScript at ./result.

### Running the ./bar application
Once the JS bundle (`.#bar-js`) of the application package *bar* is produced using `nix build .#bar-js`, we can run it directly using NodeJS:

``` sh-session
❯ node ./result
Nix, Nix
Nix, Nix
Nix, Nix
```

Alternatively: `nix run .#bar`.


## Dev shell

The dev shell is a **work-in-progress**. 

### Multi-package command (WIP)

This repo implements https://github.com/purs-nix/purs-nix/issues/36 but outside of purs-nix (see `purs-nix.nix`). It also acts as a stepping step towards actually implementing the aforementioned proposal in purs-nix itself.

- It creates a wrapper bash script to implement the above. Run `purs-nix` in devshell, and it will do the right thing depending on your $PWD. 
  - For example, `cd ./foo && purs-nix run` will try to run the foo package. This will, of course fail because there is no `Main` entry point in the foo package (unless, of course, your "output" directory already compiles compiled assets for ./bar). Try `cd ./bar && purs-nix run` instead, and it will do what `nix run` does.
- A ghost top-level ps command is also created for running `purs-nix compile` from project root. This will compile all packages. It may not make sense for non-compile commands, though.


#### Pitfals

- Non-relevant "output" directory assets can be used. For e.g., running `cd ./foo && purs-nix run` will actually succeed by running bar's entrypoint if bar had already been compiled. 
  - When purs-nix implements this properly, its "run" and "test" commands should probably ensure separation somehow.

### IDE support

Run `purs-nix compile` to compile your sources, producing an `./output` directory. This directory, in turn, will be used by the PureScript language server. This is tested to work with VSCode.

### direnv

To automatically load and unload the Nix shell environment, when entering the project, an `.envrc` can be used to invoke the Nix shell (as well as other things you may want in your development environement; see [direnv’s docs](https://direnv.net/)). A minimal example is provided:

``` sh-session
❯ cp .envrc.example .envrc
❯ $EDITOR .envrc
❯ direnv allow
```
