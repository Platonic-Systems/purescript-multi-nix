module Main (main) where

import Prelude (Unit)
import Effect (Effect)
import Effect.Console (log)

import Foo (fooFunc)

main :: Effect Unit
main = do
  log (fooFunc "Nix")
