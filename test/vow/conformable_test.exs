defmodule Vow.ConformableTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  alias Vow.Utils
  doctest Vow.Conformable

  describe "Conformable.Function.conform/5" do
    property "only accepts arity 1 functions" do
      check all fun <- VowData.wrong_pred_fun(),
                val <- term() do
        assert match?({:error, _}, Vow.conform(fun, val))
      end
    end

    property "catches raise/throw/exit from improper predicate vow" do
      check all fun <- VowData.errored_pred_fun(),
                val <- term() do
        assert match?({:error, _}, Vow.conform(fun, val))
      end
    end

    property "returns val when predicate returns true" do
      check all val <- term() do
        assert match?({:ok, ^val}, Vow.conform(fn _ -> true end, val))
      end
    end

    property "returns error when predicate returns false" do
      check all val <- term() do
        assert match?({:error, _}, Vow.conform(fn _ -> false end, val))
      end
    end
  end

  describe "Conformable.MapSet.conform/5" do
    property "if MapSet val is a subset of vow MapSet -> val" do
      check all {set, subset} <-
                  bind(
                    VowData.mapset(min_length: 1),
                    &{constant(&1), VowData.subset(&1, min_length: 1)}
                  ) do
        assert match?({:ok, ^subset}, Vow.conform(set, subset))
      end
    end

    property "if val is empty MapSet always return val" do
      check all set <- VowData.mapset(),
                val <- constant(MapSet.new([])) do
        assert match?({:ok, ^val}, Vow.conform(set, val))
      end
    end

    property "if MapSet val is not a subset of vow MapSet -> error" do
      check all {set, subset} <-
                  bind(VowData.mapset(min_length: 1), &{constant(&1), VowData.subset(&1)}) do
        non_subset = MapSet.put(subset, :foo)
        assert match?({:error, _}, Vow.conform(set, non_subset))
      end
    end

    property "empty MapSet vow matches nothing" do
      check all val <- term() do
        assert match?({:error, _}, Vow.conform(MapSet.new([]), val))
      end
    end

    property "if val member_of vow -> val" do
      check all {set, val} <-
                  bind(VowData.mapset(min_length: 1), &{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^val}, Vow.conform(set, val))
      end
    end

    property "if val not member of vow -> error" do
      check all set <- VowData.mapset(child_data: integer(1..100), min_length: 1),
                val <- integer(101..200) do
        assert match?({:error, _}, Vow.conform(set, val))
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

    property "if val not string -> error" do
      check all regex <- map(string(@regex_chars), &~r/#{&1}/),
                val <- one_of([integer(), boolean(), float()]) do
        assert match?({:error, _}, Vow.conform(regex, val))
      end
    end
  end

  describe "Conformable.Range.conform/5" do
    property "range val bounded by vow range -> val" do
      check all {range, f, l} <-
                  bind(StreamDataUtils.range(), &{constant(&1), member_of(&1), member_of(&1)}) do
        assert match?({:ok, ^f..^l}, Vow.conform(range, f..l))
      end
    end

    property "range val outside of vow range -> error(s)" do
      check all {range, vrange} <-
                  bind(StreamDataUtils.range(), fn x..y ->
                    z = if x <= y, do: y + 1, else: y - 1
                    {constant(x..y), constant(x..z)}
                  end) do
        assert match?({:error, _}, Vow.conform(range, vrange))
      end
    end

    property "range min..max succeeds with integer val b/t min and max" do
      check all {range, x} <- bind(StreamDataUtils.range(), &{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^x}, Vow.conform(range, x))
      end
    end

    property "integer val outside of range errors" do
      check all {range, x} <-
                  bind(StreamDataUtils.range(), fn x..y ->
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
      check all range <- StreamDataUtils.range(),
                x <- one_of([float(), boolean(), atom(:alphanumeric), list_of(term())]) do
        assert match?({:error, _}, Vow.conform(range, x))
      end
    end
  end

  describe "Conformable.Date.Range.conform/5" do
    property "date_range val bounded by vow date_range -> val" do
      check all {range, f, l} <-
                  bind(
                    StreamDataUtils.date_range(),
                    &{constant(&1), member_of(&1), member_of(&1)}
                  ) do
        val = Date.range(f, l)
        assert match?({:ok, ^val}, Vow.conform(range, val))
      end
    end

    property "date_range succeeds with date val b/t first and last" do
      check all {range, x} <- bind(StreamDataUtils.date_range(), &{constant(&1), member_of(&1)}) do
        assert match?({:ok, ^x}, Vow.conform(range, x))
      end
    end

    property "non-date values result in error" do
      check all range <- StreamDataUtils.date_range(),
                x <- one_of([float(), boolean(), atom(:alphanumeric), list_of(term())]),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(range, x))
      end
    end
  end

  describe "Conformable.Any.conform/5" do
    property "non-struct vow == val -> val" do
      check all vow <-
                  one_of([integer(), float(), boolean(), atom(:alphanumeric), string(:ascii)]) do
        assert match?({:ok, ^vow}, Vow.conform(vow, vow))
      end
    end

    property "non-struct vow != val -> error" do
      check all vow <-
                  one_of([integer(), float(), boolean(), atom(:alphanumeric), string(:ascii)]),
                val <- filter(term(), &(&1 != vow)) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    test "struct vow and val of differing structs -> error(s)" do
      vow = %VowStruct.Foo{a: 1, b: 2, c: 3}
      val = %VowStruct.FooCopy{a: 1, b: 2, c: 3}
      assert match?({:error, _}, Vow.conform(vow, val))
    end

    property "struct vow with valid val vow must return val as struct" do
      check all {a, b, c} <- tuple({integer(), integer(), integer()}) do
        vow = %VowStruct.Foo{a: &is_integer/1, b: &is_integer/1, c: &is_integer/1}
        val = %VowStruct.Foo{a: a, b: b, c: c}
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end
  end

  describe "Conformable.List.conform/5" do
    property "if lengths aren't equal or both aren't proper (or improper) -> error" do
      check all vow <- maybe_improper_list_of(constant(nil), constant(nil)),
                val <-
                  filter(
                    maybe_improper_list_of(constant(nil), constant(nil)),
                    &(not Utils.compatible_form?(&1, vow))
                  ) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val is not a list -> error" do
      check all vow <- maybe_improper_list_of(constant(nil), constant(nil)),
                val <- filter(term(), &(not is_list(&1))) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "valid proper list vow -> conformed val" do
      check all length <- integer(0..20),
                vow <- list_of(constant(&is_integer/1), length: length),
                val <- list_of(integer(), length: length) do
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "invalid proper list vow -> error(s)" do
      check all length <- integer(1..20),
                vow <- list_of(constant(&is_integer/1), length: length),
                val <- list_of(one_of([boolean(), float(), string(:ascii)]), length: length) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "invalid list vow -> continues to look for problems" do
      check all val <- map(tuple({integer(), float(), boolean()}), &Tuple.to_list/1) do
        vow = [&is_integer/1, &is_bitstring/1, &is_boolean/1]
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "valid (simple) improper vow succeeds" do
      check all val <-
                  map(tuple({integer(), string(:ascii), boolean()}), fn {i, s, b} ->
                    [i, s | b]
                  end) do
        vow = [&is_integer/1, (&is_bitstring/1) | &is_boolean/1]
        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end
  end

  describe "Conformable.Tuple.conform/5" do
    property "if val is not a tuple -> error" do
      check all vow <- list_of(constant(nil)),
                val <- filter(term(), &(not is_tuple(&1))),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(List.to_tuple(vow), val))
      end
    end

    property "valid tuple vow -> conformed val as tuple" do
      check all length <- integer(0..20),
                vow <- list_of(constant(&is_integer/1), length: length),
                val <- list_of(integer(), length: length) do
        val = List.to_tuple(val)
        assert match?({:ok, ^val}, Vow.conform(List.to_tuple(vow), val))
      end
    end
  end

  describe "Conformable.Map.conform/5" do
    property "if val is not a map -> error" do
      check all vow <- map_of(atom(:alphanumeric), constant(nil)),
                val <- filter(term(), &(not is_map(&1))),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val does not have all the keys in the vow -> error" do
      check all vow <- map_of(atom(:alphanumeric), constant(&is_integer/1), min_length: 1),
                vs <- list_of(integer(), length: map_size(vow)),
                key <- member_of(Map.keys(vow)),
                val =
                  vow
                  |> Map.keys()
                  |> Enum.zip(vs)
                  |> Enum.into(%{})
                  |> Map.delete(key),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val has at least all the keys in the vow -> success" do
      check all vow <- map_of(atom(:alphanumeric), constant(&is_integer/1), min_length: 1),
                vs <- list_of(integer(), length: map_size(vow)),
                extra_values <- map_of(string(:ascii), float()),
                val =
                  vow
                  |> Map.keys()
                  |> Enum.zip(vs)
                  |> Enum.into(%{})
                  |> Map.merge(extra_values),
                max_runs: 25 do
        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end

    property "valid map vow -> conformed val as map w/ same keys" do
      check all vow <- map_of(atom(:alphanumeric), constant(&is_float/1), min_length: 1),
                vs <- list_of(float(), length: map_size(vow)),
                val = Enum.into(Enum.zip(Map.keys(vow), vs), %{}),
                max_runs: 25 do
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end
  end
end
