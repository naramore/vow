defmodule VowTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  alias VowTestUtils, as: VTU
  doctest Vow

  describe "Vow.conform/2" do
    @tag skip: true
    property "returns" do
      check all spec <- VowData.spec(),
                value <- term() do
        result = Vow.conform(spec, value)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "Vow.also/1" do
    property "should always conform given zero specs" do
      check all value <- term() do
        spec = Vow.also([])
        assert match? {:ok, ^value}, Vow.conform(spec, value)
      end
    end

    property "given one spec should conform to the same value as that spec" do
      check all {ispec, spec} <- map(VowData.non_recur_spec(), &{&1, Vow.also([&1])}),
                value <- term() do
        result = Vow.conform(spec, value) |> VTU.strip_spec()
        iresult = Vow.conform(ispec, value) |> VTU.strip_spec()
        assert result == iresult
      end
    end

    property "if all specs conform -> also conforms (numbers)" do
      check all {min, max} <- tuple({integer(0..100), integer(101..200)}),
                value <- one_of([integer(min..max), float(min: min, max: max)]) do
        spec = Vow.also([&is_number/1, &(&1 >= min), &(&1 <= max)])
        assert match? {:ok, ^value}, Vow.conform(spec, value)
      end
    end

    property "if all specs conform -> also conforms (lists)" do
      check all value <- list_of(string(:ascii, min_length: 1)) do
        spec = Vow.also([
          Vow.list_of(&is_bitstring/1),
          &Enum.all?(&1, fn x -> String.length(x) > 0 end)
        ])
        assert match? {:ok, ^value}, Vow.conform(spec, value)
      end
    end

    property "if any specs fail to conform -> also fails" do
      check all value <- one_of([integer(), float()]) do
        spec = Vow.also([&is_number/1, &(not is_number(&1))])
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end

    property "recursively feeds 'conformed' values into the next specs" do
      check all value <- one_of([integer(), float(), boolean(), atom(:alphanumeric)]) do
        spec = Vow.also([
          Vow.one_of(
            i: &is_integer/1,
            b: &is_boolean/1,
            a: &is_atom/1,
            f: &is_float/1
          ),
          Vow.map_of(&is_atom/1, fn _ -> true end)
        ])
        assert match? {:ok, _}, Vow.conform(spec, value)
      end
    end
  end

  describe "Vow.one_of/1" do
    test "cannot create with no options" do
      assert_raise(FunctionClauseError, fn ->
        Vow.one_of([])
      end)
    end

    property "duplicate keys -> raise Vow.DuplicateNameError" do
      check all ks <- uniq_list_of(atom(:alphanumeric), min_length: 2),
                keys <- member_of(ks) |> map(fn k -> [k|ks] end) do
        specs = Enum.zip(keys, Stream.repeatedly(fn -> nil end))
        assert_raise(Vow.DuplicateNameError, fn ->
          Vow.one_of(specs)
        end)
      end
    end

    property "given one spec should conform to the same value as that spec wrapped in a map" do
      check all {k, i} <- tuple({atom(:alphanumeric), integer()}) do
        ispec = &is_integer/1
        spec = Vow.one_of([{k, ispec}])
        assert match? {:ok, %{^k => ^i}}, Vow.conform(spec, i)
        assert match? {:ok, ^i}, Vow.conform(ispec, i)
      end
    end

    property "if at least one spec conforms -> one_of conforms" do
      check all value <- one_of([integer(), float(), boolean(), atom(:alphanumeric)]) do
        spec = Vow.one_of([
          i: &is_integer/1,
          b: &is_boolean/1,
          a: &is_atom/1,
          f: &is_float/1
        ])
        assert match? {:ok, _}, Vow.conform(spec, value)
      end
    end

    property "conforms to the 1st spec that accepts the value" do
      check all value <- one_of([integer(), float()]) do
        spec = Vow.one_of([
          n: &is_number/1,
          i: &is_integer/1,
          f: &is_float/1
        ])
        assert match? {:ok, %{n: ^value}}, Vow.conform(spec, value)
      end
    end

    property "fails if all subspecs fail" do
      check all value <- one_of([integer(), float()]) do
        spec = Vow.one_of([
          a: &is_atom/1,
          b: &is_boolean/1
        ])
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end
  end

  describe "Vow.nilable/1" do
    property "conforms successfully if value is nil" do
      check all spec <- map(VowData.spec(), &Vow.nilable/1) do
        assert match? {:ok, _}, Vow.conform(spec, nil)
      end
    end

    @tag skip: true
    property "conform on the nilable is equivalent to conform of subspec otherwise" do
      check all spec <- map(VowData.spec(), &Vow.nilable/1),
                value <- term() do
        nilable = Vow.conform(spec, value) |> VTU.strip_spec()
        subspec = Vow.conform(spec.spec, value) |> VTU.strip_spec()
        assert nilable == subspec
      end
    end
  end

  describe "Vow.list_of/2" do
    property "if value is not a list -> error" do
      check all value <- filter(term(), &(not is_list(&1))),
                spec <- VowData.list_of() do
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end

    property "if value is improper list -> error" do
      check all value <- list_of(constant(nil), min_length: 1)
                         |> map(&VTU.to_improper/1),
                spec <- VowData.list_of() do
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end

    property "if value is larger then max length -> error" do
      check all {max, spec} <- integer(0..20) |> map(fn x -> {x, Vow.list_of(&Vow.any?/1, max_length: x)} end),
                value <- list_of(constant(nil), min_length: max + 1) do
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end

    property "if value is smaller then min length -> error" do
      check all {min, spec} <- integer(5..20) |> map(fn x -> {x, Vow.list_of(&Vow.any?/1, min_length: x)} end),
                value <- list_of(constant(nil), max_length: min - 1) do
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end

    property "if value does not contain unique elements and distinct?: true -> error" do
      check all value <- filter(list_of(integer(), min_length: 2), &(length(Enum.uniq(&1)) != length(&1))) do
        spec = Vow.list_of(&is_integer/1, distinct?: true)
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end

    property "if at least one element in value does not conform -> list_of errors" do
      check all value <- list_of(integer()),
                index <- integer(0..length(value)),
                elem <- atom(:alphanumeric),
                value = List.insert_at(value, index, elem) do
        spec = Vow.list_of(&is_integer/1)
        assert match? {:error, _}, Vow.conform(spec, value)
      end
    end

    property "if all elements in value conform to subspec -> list_of conforms" do
      check all value <- list_of(integer()) do
        spec = Vow.list_of(&is_integer/1)
        assert match? {:ok, ^value}, Vow.conform(spec, value)
      end
    end
  end

  describe "Vow.map_of/3" do
  end

  describe "Vow.merge/1" do
  end
end
