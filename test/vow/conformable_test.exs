defmodule Vow.ConformableTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  alias Vow.Conformable.List, as: SCL
  doctest Vow.Conformable

  describe "Conformable.Function.conform/5" do
    property "only accepts arity 1 functions" do
      check all fun <- VowData.wrong_pred_fun(),
                value <- term() do
        assert match?({:error, _}, Vow.conform(fun, value))
      end
    end

    property "catches raise/throw/exit from improper predicate vow" do
      check all fun <- VowData.errored_pred_fun(),
                value <- term() do
        assert match?({:error, _}, Vow.conform(fun, value))
      end
    end

    property "returns value when predicate returns true" do
      check all value <- term() do
        assert match?({:ok, ^value}, Vow.conform(fn _ -> true end, value))
      end
    end

    property "returns error when predicate returns false" do
      check all value <- term() do
        assert match?({:error, _}, Vow.conform(fn _ -> false end, value))
      end
    end
  end

  describe "Conformable.MapSet.conform/5" do
    property "if MapSet value is a subset of vow MapSet -> value" do
      check all {set, subset} <-
                  VowData.mapset(min_length: 1)
                  |> bind(&{constant(&1), VowData.subset(&1, min_length: 1)}) do
        assert match?({:ok, ^subset}, Vow.conform(set, subset))
      end
    end

    property "if value is empty MapSet always return value" do
      check all set <- VowData.mapset(),
                value <- constant(MapSet.new([])) do
        assert match?({:ok, ^value}, Vow.conform(set, value))
      end
    end

    property "if MapSet value is not a subset of vow MapSet -> error" do
      check all {set, subset} <-
                  VowData.mapset(min_length: 1)
                  |> bind(&{constant(&1), VowData.subset(&1)}) do
        non_subset = MapSet.put(subset, :foo)
        assert match?({:error, _}, Vow.conform(set, non_subset))
      end
    end

    property "empty MapSet vow matches nothing" do
      check all value <- term() do
        assert match?({:error, _}, Vow.conform(MapSet.new([]), value))
      end
    end

    property "if value member_of vow -> value" do
      check all {set, value} <-
                  VowData.mapset(min_length: 1)
                  |> bind(&{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^value}, Vow.conform(set, value))
      end
    end

    property "if value not member of vow -> error" do
      check all set <- VowData.mapset(child_data: integer(1..100), min_length: 1),
                value <- integer(101..200) do
        assert match?({:error, _}, Vow.conform(set, value))
      end
    end
  end

  describe "Conformable.Regex.conform/5" do
    @regex_chars [?a..?z, ?A..?Z, ?0..?9]

    property "should return same result as Regex.match?/2" do
      check all regex <- map(string(@regex_chars), &~r/#{&1}/),
                str <- string(:ascii) do
        result = Vow.conform(regex, str)

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
        assert match?({:error, _}, Vow.conform(regex, value))
      end
    end
  end

  describe "Conformable.Range.conform/5" do
    property "range value bounded by vow range -> value" do
      check all {range, f, l} <-
                  VowData.range()
                  |> bind(&{constant(&1), member_of(&1), member_of(&1)}) do
        assert match?({:ok, ^f..^l}, Vow.conform(range, f..l))
      end
    end

    property "range value outside of vow range -> error(s)" do
      check all {range, vrange} <-
                  VowData.range()
                  |> bind(fn x..y ->
                    z = if x <= y, do: y + 1, else: y - 1
                    {constant(x..y), constant(x..z)}
                  end) do
        assert match?({:error, _}, Vow.conform(range, vrange))
      end
    end

    property "range min..max succeeds with integer value b/t min and max" do
      check all {range, x} <-
                  VowData.range()
                  |> bind(&{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^x}, Vow.conform(range, x))
      end
    end

    property "integer value outside of range errors" do
      check all {range, x} <-
                  VowData.range()
                  |> bind(fn x..y ->
                    z =
                      if x <= y do
                        integer((y + 1)..(y + 101))
                      else
                        integer((y - 1)..(y - 101))
                      end

                    {constant(x..y), z}
                  end) do
        assert match?({:error, _}, Vow.conform(range, x))
      end
    end

    property "non-integer values result in error" do
      check all range <- VowData.range(),
                x <- one_of([float(), boolean(), atom(:alphanumeric), list_of(term())]) do
        assert match?({:error, _}, Vow.conform(range, x))
      end
    end
  end

  describe "Conformable.Date.Range.conform/5" do
    property "date_range value bounded by vow date_range -> value" do
      check all {range, f, l} <-
                  VowData.date_range()
                  |> bind(&{constant(&1), member_of(&1), member_of(&1)}) do
        value = Date.range(f, l)
        assert match?({:ok, ^value}, Vow.conform(range, value))
      end
    end

    property "date_range succeeds with date value b/t first and last" do
      check all {range, x} <-
                  VowData.date_range()
                  |> bind(&{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^x}, Vow.conform(range, x))
      end
    end

    property "non-date values result in error" do
      check all range <- VowData.date_range(),
                x <- one_of([float(), boolean(), atom(:alphanumeric), list_of(term())]),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(range, x))
      end
    end
  end

  describe "Conformable.Any.conform/5" do
    property "non-struct vow == value -> value" do
      check all vow <-
                  one_of([integer(), float(), boolean(), atom(:alphanumeric), string(:ascii)]) do
        assert match?({:ok, ^vow}, Vow.conform(vow, vow))
      end
    end

    property "non-struct vow != value -> error" do
      check all vow <-
                  one_of([integer(), float(), boolean(), atom(:alphanumeric), string(:ascii)]),
                value <- filter(term(), &(&1 != vow)) do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    test "struct vow and value of differing structs -> error(s)" do
      vow = %VowStruct.Foo{a: 1, b: 2, c: 3}
      value = %VowStruct.FooCopy{a: 1, b: 2, c: 3}
      assert match?({:error, _}, Vow.conform(vow, value))
    end

    property "struct vow with valid value vow must return value as struct" do
      check all {a, b, c} <- tuple({integer(), integer(), integer()}) do
        vow = %VowStruct.Foo{a: &is_integer/1, b: &is_integer/1, c: &is_integer/1}
        value = %VowStruct.Foo{a: a, b: b, c: c}
        assert match?({:ok, ^value}, Vow.conform(vow, value))
      end
    end
  end

  describe "Conformable.List.conform/5" do
    property "if lengths aren't equal or both aren't proper (or improper) -> error" do
      check all vow <- maybe_improper_list_of(constant(nil), constant(nil)),
                value <-
                  filter(
                    maybe_improper_list_of(constant(nil), constant(nil)),
                    &(not SCL.compatible_form?(&1, vow))
                  ) do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "if value is not a list -> error" do
      check all vow <- maybe_improper_list_of(constant(nil), constant(nil)),
                value <- filter(term(), &(not is_list(&1))) do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "valid proper list vow -> conformed value" do
      check all length <- integer(0..20),
                vow <- list_of(constant(&is_integer/1), length: length),
                value <- list_of(integer(), length: length) do
        assert match?({:ok, ^value}, Vow.conform(vow, value))
      end
    end

    property "invalid proper list vow -> error(s)" do
      check all length <- integer(1..20),
                vow <- list_of(constant(&is_integer/1), length: length),
                value <- list_of(one_of([boolean(), float(), string(:ascii)]), length: length) do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "invalid list vow -> continues to look for problems" do
      check all value <- tuple({integer(), float(), boolean()}) |> map(&Tuple.to_list/1) do
        vow = [&is_integer/1, &is_bitstring/1, &is_boolean/1]
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "valid (simple) improper vow succeeds" do
      check all value <-
                  tuple({integer(), string(:ascii), boolean()})
                  |> map(fn {i, s, b} -> [i, s | b] end) do
        vow = [&is_integer/1, (&is_bitstring/1) | &is_boolean/1]
        assert match?({:ok, _}, Vow.conform(vow, value))
      end
    end
  end

  describe "Conformable.Tuple.conform/5" do
    property "if value is not a tuple -> error" do
      check all vow <- list_of(constant(nil)),
                value <- filter(term(), &(not is_tuple(&1))),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(List.to_tuple(vow), value))
      end
    end

    property "valid tuple vow -> conformed value as tuple" do
      check all length <- integer(0..20),
                vow <- list_of(constant(&is_integer/1), length: length),
                value <- list_of(integer(), length: length) do
        value = List.to_tuple(value)
        assert match?({:ok, ^value}, Vow.conform(List.to_tuple(vow), value))
      end
    end
  end

  describe "Conformable.Map.conform/5" do
    property "if value is not a map -> error" do
      check all vow <- map_of(atom(:alphanumeric), constant(nil)),
                value <- filter(term(), &(not is_map(&1))),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "if value and vow do not have the same size -> error" do
      check all vow <- map_of(atom(:alphanumeric), constant(nil)),
                value <-
                  filter(map_of(atom(:alphanumeric), term()), &(map_size(&1) != map_size(vow))),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "if value and vow do not have all the same keys -> error" do
      check all length <- integer(1..20),
                vow <- map_of(atom(:alphanumeric), constant(nil), length: length),
                value <-
                  filter(
                    map_of(atom(:alphanumeric), term(), length: length),
                    &(not Vow.Conformable.Map.all_keys?(&1, vow))
                  ),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(vow, value))
      end
    end

    property "valid map vow -> conformed value as map w/ same keys" do
      check all vow <- map_of(atom(:alphanumeric), constant(&is_float/1), min_length: 1),
                vs <- list_of(float(), length: map_size(vow)),
                value = Enum.zip(Map.keys(vow), vs) |> Enum.into(%{}),
                max_runs: 25 do
        assert match?({:ok, ^value}, Vow.conform(vow, value))
      end
    end

    property "error problems should have keys" do
      check all k <- atom(:alphanumeric),
                v <- string(:ascii) do
        value = %{k => v}
        vow = %{k => &is_float/1}
        {:error, reason} = Vow.conform(vow, value)

        Enum.each(reason.problems, fn p ->
          assert Enum.all?(p.vow_path, &(&1 == k))
          assert Enum.all?(p.value_path, &(&1 == k))
        end)
      end
    end
  end
end
