defmodule Vow.RefTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Vow.Ref, only: [sref: 2]
  import VowTestUtils, only: [strip_via_and_vow: 1]
  doctest Vow.Ref

  describe "Vow.Ref.resolve/1" do
    setup do
      _ = VowRef.any()
      {:ok, %{}}
    end

    test "given non-atom(s) resolve errors" do
      ref = sref(VowRef, 42)
      assert match?({:error, %Vow.ResolveError{reason: nil}}, Vow.Ref.resolve(ref))
    end

    test "fun does not exist -> error" do
      ref = sref(VowRef, :not_there)
      assert match?({:error, %Vow.ResolveError{reason: nil}}, Vow.Ref.resolve(ref))
    end

    [:one_arity, :two_arity, :three_arity, :four_arity]
    |> Enum.with_index(1)
    |> Enum.map(fn {fun, i} ->
      @fun fun
      test "fun wrong arity [#{i}] -> error" do
        ref = sref(VowRef, @fun)
        assert match?({:error, %Vow.ResolveError{reason: nil}}, Vow.Ref.resolve(ref))
      end
    end)

    @reasons [:raise!, :throw!, :exit_normal!, :exit_abnormal!]

    Enum.map(@reasons, fn fun ->
      @fun fun
      test "fun raises/exits/throws [#{fun}] -> error" do
        ref = sref(VowRef, @fun)
        assert match?({:error, %Vow.ResolveError{predicate: nil}}, Vow.Ref.resolve(ref))
      end
    end)

    test "fun returns vow successfully!" do
      ref = sref(VowRef, :any)
      assert match?({:ok, _}, Vow.Ref.resolve(ref))
    end
  end

  describe "Vow.Conformable.Vow.Ref.conform/5" do
    property "successfully conform against referenced vow" do
      check all val <- term() do
        vow = sref(VowRef, :any)
        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end

    property "fail to conform against referenced vow" do
      check all val <- term() do
        vow = sref(VowRef, :none)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "#SRef<*vow*> == *vow*" do
      check all data <- VowRef.clj_vow_gen(),
                max_runs: 25 do
        ref = sref(VowRef, :clj_vow)
        yay_ref = Vow.conform(ref, data)
        nay_ref = Vow.conform(VowRef.clj_vow(), data)
        assert strip_via_and_vow(yay_ref) == strip_via_and_vow(nay_ref)
      end
    end
  end

  describe "Vow.RegexOperator.Vow.Ref.conform/5" do
    property "#SRef<*regex-op*> == *regex-op* when called from a regex-op" do
      check all data <- VowRef.clj_regexop_gen(),
                max_runs: 25 do
        ref = sref(VowRef, :clj_regexop)
        yay_ref = Vow.conform(ref, data)
        nay_ref = Vow.conform(VowRef.clj_regexop(), data)
        assert strip_via_and_vow(yay_ref) == strip_via_and_vow(nay_ref)
      end
    end
  end
end
