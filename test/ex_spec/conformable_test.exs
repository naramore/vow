defmodule ExSpec.ConformableTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  alias ExSpec.Conformable.List, as: SCL
  doctest ExSpec.Conformable

  describe "Conformable.Function.conform/5" do
    property "only accepts arity 1 functions" do
      check all fun <- ExSpecData.wrong_pred_fun(),
                value <- term() do
        assert match?({:error, _}, ExSpec.conform(fun, value))
      end
    end

    property "catches raise/throw/exit from improper predicate spec" do
      check all fun <- ExSpecData.errored_pred_fun(),
                value <- term() do
        assert match?({:error, _}, ExSpec.conform(fun, value))
      end
    end

    property "returns value when predicate returns true" do
      check all value <- term() do
        assert match?({:ok, ^value}, ExSpec.conform(fn _ -> true end, value))
      end
    end

    property "returns error when predicate returns false" do
      check all value <- term() do
        assert match?({:error, _}, ExSpec.conform(fn _ -> false end, value))
      end
    end
  end

  describe "Conformable.MapSet.conform/5" do
    property "if MapSet value is a subset of spec MapSet -> value" do
      check all {set, subset} <-
                  ExSpecData.mapset(min_length: 1)
                  |> bind(&{constant(&1), ExSpecData.subset(&1, min_length: 1)}) do
        assert match?({:ok, ^subset}, ExSpec.conform(set, subset))
      end
    end

    property "if value is empty MapSet always return value" do
      check all set <- ExSpecData.mapset(),
                value <- constant(MapSet.new([])) do
        assert match?({:ok, ^value}, ExSpec.conform(set, value))
      end
    end

    property "if MapSet value is not a subset of spec MapSet -> error" do
      check all {set, subset} <-
                  ExSpecData.mapset(min_length: 1)
                  |> bind(&{constant(&1), ExSpecData.subset(&1)}) do
        non_subset = MapSet.put(subset, :foo)
        assert match?({:error, _}, ExSpec.conform(set, non_subset))
      end
    end

    property "empty MapSet spec matches nothing" do
      check all value <- term() do
        assert match?({:error, _}, ExSpec.conform(MapSet.new([]), value))
      end
    end

    property "if value member_of spec -> value" do
      check all {set, value} <-
                  ExSpecData.mapset(min_length: 1)
                  |> bind(&{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^value}, ExSpec.conform(set, value))
      end
    end

    property "if value not member of spec -> error" do
      check all set <- ExSpecData.mapset(child_data: integer(1..100), min_length: 1),
                value <- integer(101..200) do
        assert match?({:error, _}, ExSpec.conform(set, value))
      end
    end
  end

  describe "Conformable.Regex.conform/5" do
    @regex_chars [?a..?z, ?A..?Z, ?0..?9]

    property "should return same result as Regex.match?/2" do
      check all regex <- map(string(@regex_chars), &~r/#{&1}/),
                str <- string(:ascii) do
        result = ExSpec.conform(regex, str)

        if match?({:ok, _}, result) do
          assert Regex.match?(regex, str)
        else
          refute Regex.match?(regex, str)
        end
      end
    end

    property "if value not string -> error" do
      check all regex <- map(string(@regex_chars), &~r/#{&1}/),
                value <- one_of([integer(), boolean(), float()]) do
        assert match?({:error, _}, ExSpec.conform(regex, value))
      end
    end
  end

  describe "Conformable.Range.conform/5" do
    property "range value bounded by spec range -> value" do
      check all {range, f, l} <-
                  ExSpecData.range()
                  |> bind(&{constant(&1), member_of(&1), member_of(&1)}) do
        assert match?({:ok, ^f..^l}, ExSpec.conform(range, f..l))
      end
    end

    property "range value outside of spec range -> error(s)" do
      check all {range, vrange} <-
                  ExSpecData.range()
                  |> bind(fn x..y ->
                    z = if x <= y, do: y + 1, else: y - 1
                    {constant(x..y), constant(x..z)}
                  end) do
        assert match?({:error, _}, ExSpec.conform(range, vrange))
      end
    end

    property "range min..max succeeds with integer value b/t min and max" do
      check all {range, x} <-
                  ExSpecData.range()
                  |> bind(&{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^x}, ExSpec.conform(range, x))
      end
    end

    property "integer value outside of range errors" do
      check all {range, x} <-
                  ExSpecData.range()
                  |> bind(fn x..y ->
                    z =
                      if x <= y do
                        integer((y + 1)..(y + 101))
                      else
                        integer((y - 1)..(y - 101))
                      end

                    {constant(x..y), z}
                  end) do
        assert match?({:error, _}, ExSpec.conform(range, x))
      end
    end

    property "non-integer values result in error" do
      check all range <- ExSpecData.range(),
                x <- one_of([float(), boolean(), atom(:alphanumeric), list_of(term())]) do
        assert match?({:error, _}, ExSpec.conform(range, x))
      end
    end
  end

  describe "Conformable.Date.Range.conform/5" do
    property "date_range value bounded by spec date_range -> value" do
      check all {range, f, l} <-
                  ExSpecData.date_range()
                  |> bind(&{constant(&1), member_of(&1), member_of(&1)}) do
        value = Date.range(f, l)
        assert match?({:ok, ^value}, ExSpec.conform(range, value))
      end
    end

    property "date_range succeeds with date value b/t first and last" do
      check all {range, x} <-
                  ExSpecData.date_range()
                  |> bind(&{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^x}, ExSpec.conform(range, x))
      end
    end

    property "non-date values result in error" do
      check all range <- ExSpecData.date_range(),
                x <- one_of([float(), boolean(), atom(:alphanumeric), list_of(term())]) do
        assert match?({:error, _}, ExSpec.conform(range, x))
      end
    end
  end

  describe "Conformable.Any.conform/5" do
    property "non-struct spec == value -> value" do
      check all spec <-
                  one_of([integer(), float(), boolean(), atom(:alphanumeric), string(:ascii)]) do
        assert match?({:ok, ^spec}, ExSpec.conform(spec, spec))
      end
    end

    property "non-struct spec != value -> error" do
      check all spec <-
                  one_of([integer(), float(), boolean(), atom(:alphanumeric), string(:ascii)]),
                value <- filter(term(), &(&1 != spec)) do
        assert match?({:error, _}, ExSpec.conform(spec, value))
      end
    end

    test "struct spec and value of differing structs -> error(s)" do
      spec = %ExSpecStruct.Foo{a: 1, b: 2, c: 3}
      value = %ExSpecStruct.FooCopy{a: 1, b: 2, c: 3}
      assert match?({:error, _}, ExSpec.conform(spec, value))
    end

    property "struct spec with valid value spec must return value as struct" do
      check all {a, b, c} <- tuple({integer(), integer(), integer()}) do
        spec = %ExSpecStruct.Foo{a: &is_integer/1, b: &is_integer/1, c: &is_integer/1}
        value = %ExSpecStruct.Foo{a: a, b: b, c: c}
        assert match?({:ok, ^value}, ExSpec.conform(spec, value))
      end
    end
  end

  describe "Conformable.List.conform/5" do
    property "if lengths aren't equal or both aren't proper (or improper) -> error" do
      check all spec <- maybe_improper_list_of(constant(nil), constant(nil)),
                value <-
                  filter(
                    maybe_improper_list_of(constant(nil), constant(nil)),
                    &(not SCL.compatible_form?(&1, spec))
                  ) do
        assert match?({:error, _}, ExSpec.conform(spec, value))
      end
    end

    property "if value is not a list -> error" do
      check all spec <- maybe_improper_list_of(constant(nil), constant(nil)),
                value <- filter(term(), &(not is_list(&1))) do
        assert match?({:error, _}, ExSpec.conform(spec, value))
      end
    end

    property "valid proper list spec -> conformed value" do
      check all length <- integer(0..20),
                spec <- list_of(constant(&is_integer/1), length: length),
                value <- list_of(integer(), length: length) do
        assert match?({:ok, ^value}, ExSpec.conform(spec, value))
      end
    end

    property "invalid proper list spec -> error(s)" do
      check all length <- integer(1..20),
                spec <- list_of(constant(&is_integer/1), length: length),
                value <- list_of(one_of([boolean(), float(), string(:ascii)]), length: length) do
        assert match?({:error, _}, ExSpec.conform(spec, value))
      end
    end
  end

  describe "Conformable.Tuple.conform/5" do
    property "if value is not a tuple -> error" do
      check all spec <- list_of(constant(nil)),
                value <- filter(term(), &(not is_tuple(&1))) do
        assert match?({:error, _}, ExSpec.conform(List.to_tuple(spec), value))
      end
    end

    property "valid tuple spec -> conformed value as tuple" do
      check all length <- integer(0..20),
                spec <- list_of(constant(&is_integer/1), length: length),
                value <- list_of(integer(), length: length) do
        value = List.to_tuple(value)
        assert match?({:ok, ^value}, ExSpec.conform(List.to_tuple(spec), value))
      end
    end
  end

  describe "Conformable.Map.conform/5" do
    property "if value is not a map -> error" do
      check all spec <- map_of(atom(:alphanumeric), constant(nil)),
                value <- filter(term(), &(not is_map(&1))) do
        assert match?({:error, _}, ExSpec.conform(spec, value))
      end
    end

    property "if value and spec do not have the same size -> error" do
      check all spec <- map_of(atom(:alphanumeric), constant(nil)),
                value <-
                  filter(map_of(atom(:alphanumeric), term()), &(map_size(&1) != map_size(spec))) do
        assert match?({:error, _}, ExSpec.conform(spec, value))
      end
    end

    property "if value and spec do not have all the same keys -> error" do
      check all length <- integer(1..20),
                spec <- map_of(atom(:alphanumeric), constant(nil), length: length),
                value <-
                  filter(
                    map_of(atom(:alphanumeric), term(), length: length),
                    &(not ExSpec.Conformable.Map.all_keys?(&1, spec))
                  ) do
        assert match?({:error, _}, ExSpec.conform(spec, value))
      end
    end

    property "valid map spec -> conformed value as map w/ same keys" do
      check all spec <- map_of(atom(:alphanumeric), constant(&is_float/1), min_length: 1),
                vs <- list_of(float(), length: map_size(spec)),
                value = Enum.zip(Map.keys(spec), vs) |> Enum.into(%{}) do
        assert match?({:ok, ^value}, ExSpec.conform(spec, value))
      end
    end
  end
end
