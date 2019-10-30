defmodule Vow.RegexOperatorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias VowTestUtils, as: VTU
  doctest Vow.RegexOperator

  describe "Vow.Conformable.conform/5 for: RegexOperators" do
    property "will error if given value is an improper list" do
      check all value <- list_of(boolean(), min_length: 1) |> map(&VTU.to_improper/1),
                vow <- VowData.regex_vow(constant(nil)) do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "will error if given value is a not an enumerable" do
      check all value <-
                  one_of([integer(), float(), boolean(), atom(:alphanumeric), string(:ascii)]),
                vow <- VowData.regex_vow(constant(nil)) do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "will error if Vow.RegexOperator.conform/5 returns partial match" do
      check all value <-
                  tuple(
                    {list_of(integer(), min_length: 1), list_of(string(:ascii), min_length: 1)}
                  )
                  |> map(fn {is, ss} -> is ++ ss end) do
        vow = Vow.oom(&is_integer/1)
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "will error if Vow.RegexOperator.conform/5 returns error" do
      check all value <- list_of(boolean(), min_length: 1) do
        vow = Vow.oom(&is_integer/1)
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "will succeed if Vow.RegexOperator.conform/5 returns full match" do
      check all value <- list_of(string(:ascii)) do
        vow = Vow.zom(&is_bitstring/1)
        assert match?({:ok, _}, Vow.conform(vow, value))
      end
    end
  end
end
