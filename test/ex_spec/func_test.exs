defmodule ExSpec.FuncTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  doctest ExSpec.Func
end
