defmodule VowTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  alias VowTestUtils, as: VTU
  doctest Vow

  describe "Vow.conform/2" do
    @tag skip: true
    property "returns" do
      check all vow <- VowData.vow(),
                val <- term(),
                max_runs: 25 do
        result = Vow.conform(vow, val)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "Vow.conform!/2" do
    property "should raise a ConformError if failed" do
      check all val <- term(), max_runs: 25 do
        vow = VowRef.none()

        assert_raise(Vow.ConformError, fn ->
          Vow.conform!(vow, val)
        end)
      end
    end

    property "should return val if conformed successfully" do
      check all val <- term() do
        vow = VowRef.any()
        assert val == Vow.conform!(vow, val)
      end
    end
  end

  describe "Vow.valid?/2" do
    property "should return true if val conforms to vow" do
      check all val <- term() do
        vow = VowRef.any()
        assert Vow.valid?(vow, val)
      end
    end

    property "should return false if val fails to conform to vow" do
      check all val <- term() do
        vow = VowRef.none()
        refute Vow.valid?(vow, val)
      end
    end
  end

  property "Vow.invalid?/2 should always return opposite of Vow.valid?/2" do
    check all val <- one_of([boolean(), integer(), float(), string(:ascii)]),
              vow <- VowData.non_recur_vow() do
      assert VTU.complement(Vow.invalid?(vow, val)) == Vow.valid?(vow, val)
    end
  end

  property "Vow.set/2 is a shortcut for MapSet.new/1" do
    check all values <- list_of(term()), max_runs: 50 do
      assert Vow.set(values) == MapSet.new(values)
    end
  end

  describe "Vow.also/1" do
    property "should always conform given zero vows" do
      check all val <- term() do
        vow = Vow.also([])
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "given one vow should conform to the same val as that vow" do
      check all {ivow, vow} <- map(VowData.non_recur_vow(), &{&1, Vow.also(i: &1)}),
                val <- term() do
        result = Vow.conform(vow, val)
        iresult = Vow.conform(ivow, val)
        assert VTU.strip_vow_and_path(result) == VTU.strip_vow_and_path(iresult)
      end
    end

    property "if all vows conform -> also conforms (numbers)" do
      check all {min, max} <- tuple({integer(0..100), integer(101..200)}),
                val <- one_of([integer(min..max), float(min: min, max: max)]) do
        vow = Vow.also(n: &is_number/1, gt: &(&1 >= min), lt: &(&1 <= max))
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "if all vows conform -> also conforms (lists)" do
      check all val <- list_of(string(:ascii, min_length: 1)) do
        vow =
          Vow.also(
            l: Vow.list_of(&is_bitstring/1),
            a: &Enum.all?(&1, fn x -> String.length(x) > 0 end)
          )

        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "if any vows fail to conform -> also fails" do
      check all val <- one_of([integer(), float()]) do
        vow = Vow.also(n: &is_number/1, nn: &(not is_number(&1)))
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "recursively feeds 'conformed' values into the next vows" do
      check all val <- one_of([integer(), float(), boolean(), atom(:alphanumeric)]) do
        vow =
          Vow.also(
            s:
              Vow.one_of(
                i: &is_integer/1,
                b: &is_boolean/1,
                a: &is_atom/1,
                f: &is_float/1
              ),
            m: Vow.map_of(&is_atom/1, fn _ -> true end)
          )

        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end
  end

  describe "Vow.one_of/1" do
    property "should raise given an unnamed list of vows" do
      check all vows <- list_of(tuple({atom(:alphanumeric), constant(nil)}), min_length: 1),
                index <- integer(0..length(vows)),
                bad_vows = List.insert_at(vows, index, nil) do
        assert_raise(Vow.UnnamedVowsError, fn ->
          Vow.one_of(bad_vows)
        end)
      end
    end

    test "cannot create with no options" do
      assert_raise(FunctionClauseError, fn ->
        Vow.one_of([])
      end)
    end

    property "duplicate keys -> raise Vow.DuplicateNameError" do
      check all ks <- uniq_list_of(atom(:alphanumeric), min_length: 2),
                keys <- map(member_of(ks), fn k -> [k | ks] end) do
        vows = Enum.zip(keys, Stream.repeatedly(fn -> nil end))

        assert_raise(Vow.DuplicateNameError, fn ->
          Vow.one_of(vows)
        end)
      end
    end

    property "given one vow should conform to the same val as that vow wrapped in a map" do
      check all {k, i} <- tuple({atom(:alphanumeric), integer()}) do
        ivow = &is_integer/1
        vow = Vow.one_of([{k, ivow}])
        assert match?({:ok, %{^k => ^i}}, Vow.conform(vow, i))
        assert match?({:ok, ^i}, Vow.conform(ivow, i))
      end
    end

    property "if at least one vow conforms -> one_of conforms" do
      check all val <- one_of([integer(), float(), boolean(), atom(:alphanumeric)]) do
        vow =
          Vow.one_of(
            i: &is_integer/1,
            b: &is_boolean/1,
            a: &is_atom/1,
            f: &is_float/1
          )

        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end

    property "conforms to the 1st vow that accepts the val" do
      check all val <- one_of([integer(), float()]) do
        vow =
          Vow.one_of(
            n: &is_number/1,
            i: &is_integer/1,
            f: &is_float/1
          )

        assert match?({:ok, %{n: ^val}}, Vow.conform(vow, val))
      end
    end

    property "fails if all subvows fail" do
      check all val <- one_of([integer(), float()]) do
        vow =
          Vow.one_of(
            a: &is_atom/1,
            b: &is_boolean/1
          )

        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end
  end

  describe "Vow.nilable/1" do
    property "conforms successfully if val is nil" do
      check all vow <- map(VowData.vow(), &Vow.nilable/1) do
        assert match?({:ok, _}, Vow.conform(vow, nil))
      end
    end

    property "conform on the nilable is equivalent to conform of subvow otherwise" do
      check all vow <- VowData.nilable(VowData.non_recur_vow()),
                val <- one_of([boolean(), integer(), float(), string(:ascii)]) do
        nilable = Vow.conform(vow, val)
        subvow = Vow.conform(vow.vow, val)
        assert VTU.strip_vow(nilable) == VTU.strip_vow(subvow)
      end
    end

    property "unform should return nil given nil" do
      check all vow <- map(VowData.vow(), &Vow.nilable/1) do
        assert match?({:ok, nil}, Vow.unform(vow, nil))
      end
    end

    property "unform on nilable == unform on inner vow" do
      check all vow <- VowData.nilable(VowData.non_recur_vow()),
                val <- one_of([boolean(), integer(), float(), string(:ascii)]) do
        assert Vow.unform(vow, val) == Vow.unform(vow.vow, val)
      end
    end
  end

  describe "Vow.list_of/2" do
    property "if val is not a list -> error" do
      check all val <- filter(term(), &(not is_list(&1))),
                vow <- VowData.list_of(),
                max_runs: 25 do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val is improper list -> error" do
      check all val <- map(list_of(constant(nil), min_length: 1), &VTU.to_improper/1),
                vow <- VowData.list_of() do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val is larger then max length -> error" do
      check all {max, vow} <-
                  map(integer(0..20), fn x -> {x, Vow.list_of(&Vow.any?/1, max_length: x)} end),
                val <- list_of(constant(nil), min_length: max + 1) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val is smaller then min length -> error" do
      check all {min, vow} <-
                  map(integer(5..20), fn x -> {x, Vow.list_of(&Vow.any?/1, min_length: x)} end),
                val <- list_of(constant(nil), max_length: min - 1) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val does not contain unique elements and distinct?: true -> error" do
      check all val <- list_of(integer(), min_length: 2),
                index <- integer(0..length(val)),
                elem <- member_of(val),
                val = List.insert_at(val, index, elem) do
        vow = Vow.list_of(&is_integer/1, distinct?: true)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if at least one element in val does not conform -> list_of errors" do
      check all val <- list_of(integer()),
                index <- integer(0..length(val)),
                elem <- atom(:alphanumeric),
                val = List.insert_at(val, index, elem) do
        vow = Vow.list_of(&is_integer/1)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if all elements in val conform to subvow -> list_of conforms" do
      check all val <- list_of(integer()) do
        vow = Vow.list_of(&is_integer/1)
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end
  end

  describe "Vow.map_of/3" do
    property "if val is not a map -> error" do
      check all val <- filter(term(), &(not is_map(&1))), vow <- VowData.map_of(), max_runs: 25 do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if at least one kv-pair in val does not conform -> map_of errors" do
      check all val <- map_of(atom(:alphanumeric), integer()),
                k <- filter(atom(:alphanumeric), &(&1 not in Map.keys(val))),
                v <- atom(:alphanumeric),
                val = Map.put(val, k, v) do
        vow = Vow.map_of(&is_atom/1, &is_integer/1)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if all elements in val conform to subvow -> map_of conforms" do
      check all val <- map_of(atom(:alphanumeric), integer()) do
        vow = Vow.map_of(&is_atom/1, &is_integer/1)
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "conform_keys?: true forces the map keys to be conformed" do
      check all val <-
                  map_of(
                    one_of([atom(:alphanumeric), string(:ascii)]),
                    integer(),
                    min_length: 1
                  ) do
        vow =
          Vow.map_of(
            Vow.one_of(a: &is_atom/1, s: &is_bitstring/1),
            &is_integer/1,
            conform_keys?: true
          )

        result = Vow.conform(vow, val)
        assert match?({:ok, _}, result)
        refute match?({:ok, ^val}, result)
      end
    end

    property "conform_keys?: false does not change keys" do
      check all val <-
                  map_of(
                    one_of([atom(:alphanumeric), string(:ascii)]),
                    integer()
                  ) do
        vow =
          Vow.map_of(
            Vow.one_of(a: &is_atom/1, s: &is_bitstring/1),
            &is_integer/1,
            conform_keys?: false
          )

        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "if key vow is simple -> conform_keys? does nothing" do
      check all val <- map_of(string(:ascii), integer()),
                conform_keys? <- boolean() do
        vow = Vow.map_of(&is_bitstring/1, &is_integer/1, conform_keys?: conform_keys?)
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "if val is larger then max length -> error" do
      check all {max, vow} <-
                  map(integer(0..20), fn x ->
                    {x, Vow.map_of(&Vow.any?/1, &Vow.any?/1, max_length: x)}
                  end),
                val <- map_of(atom(:alphanumeric), constant(nil), min_length: max + 1) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if val is smaller then min length -> error" do
      check all {min, vow} <-
                  map(integer(5..20), fn x ->
                    {x, Vow.map_of(&Vow.any?/1, &Vow.any?/1, min_length: x)}
                  end),
                val <- map_of(atom(:alphanumeric), constant(nil), max_length: min - 1) do
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end
  end

  describe "Vow.keyword_of/2" do
    property "succeeds if val valid keyword list" do
      check all val <- keyword_of(integer()) do
        vow = Vow.keyword_of(&is_integer/1)
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end
  end

  describe "Vow.merge/2" do
    property "fails to conform if not given a map" do
      check all val <- one_of([boolean(), integer(), float(), string(:ascii)]) do
        vow = Vow.merge([%{}, %{}])
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "returns the val itself if val is map and merge is empty" do
      check all val <- map_of(atom(:alphanumeric), constant(nil)) do
        vow = Vow.merge([])
        assert match?({:ok, ^val}, Vow.conform(vow, val))
      end
    end

    property "if any of the inner vows fail -> the merge vow fails" do
      check all others <- map_of(atom(:alphanumeric), one_of([boolean(), atom(:alphanumeric)])),
                {a, b} <- tuple({atom(:alphanumeric), boolean()}),
                val = Map.merge(others, %{a: a, b: b}) do
        vow =
          Vow.merge(
            fm1: %{a: &is_atom/1, b: &is_boolean/1},
            mo: Vow.map_of(&is_atom/1, Vow.one_of(b: &is_boolean/1, a: &is_atom/1)),
            fm2: %{a: &is_integer/1}
          )

        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if all inner vows succeed -> return the merge of all returned maps" do
      check all others <- map_of(atom(:alphanumeric), one_of([boolean(), atom(:alphanumeric)])),
                {a, b} <- tuple({atom(:alphanumeric), boolean()}),
                val = Map.merge(others, %{a: a, b: b}) do
        vow =
          Vow.merge(
            fm: %{a: &is_atom/1, b: &is_boolean/1},
            mo: Vow.map_of(&is_atom/1, Vow.one_of(b: &is_boolean/1, a: &is_atom/1))
          )

        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end

    property "the order of merges can effect the result" do
      check all val <-
                  {integer(), boolean(), string(:ascii), one_of([integer(), float()])}
                  |> tuple()
                  |> map(fn {w, x, y, z} -> %{a: w, b: x, c: y, d: z} end) do
        a = %{a: &is_integer/1, b: &is_boolean/1}
        b = %{c: &is_bitstring/1, d: &is_number/1}
        c = %{d: Vow.one_of(i: &is_integer/1, f: &is_float/1)}

        refute Vow.conform(Vow.merge(a: a, b: b, c: c), val) ==
                 Vow.conform(Vow.merge(a: a, c: c, b: b), val)
      end
    end
  end

  describe "Vow.keys/1" do
    property "fails to conform if not given a map" do
      check all val <- tree(one_of([boolean(), integer(), float(), string(:ascii)]), &list_of/1) do
        vow = Vow.keys(required: [:i, :n, :f], default_module: VowRef)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    @duplicate_keys [
      simple: [:i, :n, :n],
      with_or: [:i, {VowRef, :n}, {:or, [:s, :i]}],
      nested: [Vow.Ref.new(VowRef, :i), {:or, [:n, {:and, [:i, :f]}]}]
    ]

    Enum.map(@duplicate_keys, fn {name, keys} ->
      @name name
      @keys keys
      test "throws if given duplicate keys [#{@name}]" do
        assert_raise(Vow.DuplicateKeyError, fn ->
          Vow.keys(required: @keys, default_module: VowRef)
        end)
      end
    end)

    property "if all required keys do not exist -> conform will fail" do
      check all {i, f, b, s} <- tuple({integer(), float(), boolean(), string(:ascii)}),
                map = %{i: i, f: f, b: b, s: s},
                key <- member_of(Map.keys(map)),
                val = Map.delete(map, key) do
        vow = Vow.keys(required: [:i, :f, :b, :s], default_module: VowRef)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if any key refs do not exist -> conform will fail" do
      check all {i, f, b, s} <- tuple({integer(), float(), boolean(), string(:ascii)}),
                val = %{i: i, f: f, b: b, ss: s} do
        vow = Vow.keys(required: [:i, :f, :b, :ss], default_module: VowRef)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if any of the optional keys do not exist -> conform will not fail" do
      check all {i, f, b, s} <- tuple({integer(), float(), boolean(), string(:ascii)}),
                map = %{i: i, f: f, b: b, s: s},
                key <- member_of(Map.keys(map)),
                val = Map.delete(map, key) do
        vow = Vow.keys(optional: [:i, :f, :b, :s], default_module: VowRef)
        refute match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "if any values do not conform -> conform will fail" do
      check all {i, f, b, s} <- tuple({integer(), integer(), boolean(), string(:ascii)}),
                val = %{i: i, f: f, b: b, s: s} do
        vow = Vow.keys(required: [:i, :f, :b, :s], default_module: VowRef)
        assert match?({:error, _}, Vow.conform(vow, val))
      end
    end

    property "{:or, [...]} will match the 1st key that exists and conforms" do
      check all val <-
                  {integer(), one_of([float(), string(:ascii)])}
                  |> tuple()
                  |> map(fn
                    {i, f} when is_float(f) -> %{i: i, f: f}
                    {i, s} -> %{i: i, s: s}
                  end) do
        vow = Vow.keys(required: [:i, {:or, [:f, :s]}], default_module: VowRef)
        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end

    property "{:and, [...]} will match only if all keys exist and conform" do
      check all val <-
                  {integer(), one_of([string(:ascii), tuple({boolean(), float()})])}
                  |> tuple()
                  |> map(fn
                    {i, {b, f}} -> %{i: i, b: b, f: f}
                    {i, s} -> %{i: i, s: s}
                  end) do
        vow = Vow.keys(required: [:i, {:or, [:s, {:and, [:b, :f]}]}], default_module: VowRef)
        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end

    property "if all keys exist and values conform -> conform will succeed" do
      check all {i, f, b, s} <- tuple({integer(), float(), boolean(), string(:ascii)}),
                val = %{i: i, f: f, b: b, s: s} do
        vow = Vow.keys(required: [:i, :f, :b, :s], default_module: VowRef)
        assert match?({:ok, _}, Vow.conform(vow, val))
      end
    end
  end
end
