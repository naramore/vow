defmodule ExSpec.RefTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import ExSpec.Ref, only: [sref: 2]
  doctest ExSpec.Ref

  describe "ExSpec.Ref.resolve/1" do
    setup do
      _ = ExSpecRef.any()
      {:ok, %{}}
    end

    test "fun does not exist -> error" do
      ref = sref(ExSpecRef, :not_there)
      assert match?({:error, [{_, nil}]}, ExSpec.Ref.resolve(ref))
    end

    [:one_arity, :two_arity, :three_arity, :four_arity]
    |> Enum.with_index(1)
    |> Enum.map(fn {fun, i} ->
      @fun fun
      test "fun wrong arity [#{i}] -> error" do
        ref = sref(ExSpecRef, @fun)
        assert match?({:error, [{_, nil}]}, ExSpec.Ref.resolve(ref))
      end
    end)

    [:raise!, :throw!, :exit_normal!, :exit_abnormal!]
    |> Enum.map(fn fun ->
      @fun fun
      test "fun raises/exits/throws [#{fun}] -> error" do
        ref = sref(ExSpecRef, @fun)
        assert match?({:error, [{nil, _}]}, ExSpec.Ref.resolve(ref))
      end
    end)

    test "fun returns spec successfully!" do
      ref = sref(ExSpecRef, :any)
      assert match?({:ok, _}, ExSpec.Ref.resolve(ref))
    end
  end

  describe "ExSpec.Conformable.ExSpec.Ref.conform/5" do
    property "#SRef<*spec*> == *spec*" do
      check all data <- ExSpecRef.clj_spec_gen() do
        ref = sref(ExSpecRef, :clj_spec)
        yay_ref = ExSpec.conform(ref, data) |> strip_conformed()
        nay_ref = ExSpec.conform(ExSpecRef.clj_spec(), data) |> strip_conformed()
        assert yay_ref == nay_ref
      end
    end
  end

  describe "ExSpec.RegexOperator.ExSpec.Ref.conform/5" do
    property "#SRef<*regex-op*> == *regex-op* when called from a regex-op" do
      check all data <- ExSpecRef.clj_regexop_gen() do
        ref = sref(ExSpecRef, :clj_regexop)
        yay_ref = ExSpec.conform(ref, data) |> strip_conformed()
        nay_ref = ExSpec.conform(ExSpecRef.clj_regexop(), data) |> strip_conformed()
        assert yay_ref == nay_ref
      end
    end
  end

  defp strip_conformed({:ok, _} = result), do: result

  defp strip_conformed({:error, error}) do
    problems = Enum.map(error.problems, &%{&1 | via: []})
    {:error, %{error | problems: problems, spec: nil}}
  end
end
