module Main (main) where

import Prelude
import Effect (Effect)
import Effect.Console (log)
import Foo (fooFunc)

foreign import zalgoize ∷ String → String

main ∷ Effect Unit
main = do
  log <<< zalgoize $ fooFunc "Nix"
