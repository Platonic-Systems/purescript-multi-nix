module Foo (fooFunc) where

import Matrix (repeat, prettyPrintMatrix)

fooFunc :: String -> String
fooFunc s =
  prettyPrintMatrix (\a -> a) (repeat 2 3 s)
