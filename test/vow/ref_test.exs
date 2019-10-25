defmodule Vow.RefTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Vow.Ref, only: [sref: 2]
  import VowTestUtils, only: [strip_via_and_spec: 1]
  doctest Vow.Ref

  describe "Vow.Ref.resolve/1" do
    setup do
      _ = VowRef.any()
      {:ok, %{}}
    end

    test "fun does not exist -> error" do
      ref = sref(VowRef, :not_there)
      assert match?({:error, [{_, nil}]}, Vow.Ref.resolve(ref))
    end

    [:one_arity, :two_arity, :three_arity, :four_arity]
    |> Enum.with_index(1)
    |> Enum.map(fn {fun, i} ->
      @fun fun
      test "fun wrong arity [#{i}] -> error" do
        ref = sref(VowRef, @fun)
        assert match?({:error, [{_, nil}]}, Vow.Ref.resolve(ref))
      end
    end)

    [:raise!, :throw!, :exit_normal!, :exit_abnormal!]
    |> Enum.map(fn fun ->
      @fun fun
      test "fun raises/exits/throws [#{fun}] -> error" do
        ref = sref(VowRef, @fun)
        assert match?({:error, [{nil, _}]}, Vow.Ref.resolve(ref))
      end
    end)

    test "fun returns spec successfully!" do
      ref = sref(VowRef, :any)
      assert match?({:ok, _}, Vow.Ref.resolve(ref))
    end
  end

  describe "Vow.Conformable.Vow.Ref.conform/5" do
    property "#SRef<*spec*> == *spec*" do
      check all data <- VowRef.clj_spec_gen() do
        ref = sref(VowRef, :clj_spec)
        yay_ref = Vow.conform(ref, data) |> strip_via_and_spec()
        nay_ref = Vow.conform(VowRef.clj_spec(), data) |> strip_via_and_spec()
        assert yay_ref == nay_ref
      end
    end
  end

  describe "Vow.RegexOperator.Vow.Ref.conform/5" do
    @tag skip: true
    property "#SRef<*regex-op*> == *regex-op* when called from a regex-op" do
      check all data <- VowRef.clj_regexop_gen() do
        ref = sref(VowRef, :clj_regexop)
        yay_ref = Vow.conform(ref, data) |> strip_via_and_spec()
        nay_ref = Vow.conform(VowRef.clj_regexop(), data) |> strip_via_and_spec()
        assert yay_ref == nay_ref
      end
    end
  end
end
