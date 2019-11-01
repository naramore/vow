defmodule VowRegexTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  alias VowTestUtils, as: VTU

  describe "All RegexOperators" do
    property "given a non-list should fail to conform" do
      check all value <- one_of([boolean(), integer(), float(), string(:ascii)]),
                vow <- VowData.regex_vow(),
                max_runs: 40 do
        assert match?({:error, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "given an improper list should fail to conform" do
      check all value <- list_of(constant(nil), min_length: 1) |> map(&VTU.to_improper/1),
                vow <- VowData.regex_vow(),
                max_runs: 40 do
        assert match?({:error, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "given a partial match will conform and return non-matching part" do
      check all {vow, value} <-
                  one_of([
                    tuple({
                      constant(Vow.alt(n: &is_number/1, s: &is_bitstring/1)),
                      list_of(one_of([integer(), string(:ascii)]), min_length: 2)
                    }),
                    tuple({
                      constant(
                        Vow.amp(
                          Vow.maybe(&is_integer/1),
                          &(List.first(&1) > 42)
                        )
                      ),
                      list_of(integer(43..100), min_length: 2)
                    }),
                    tuple({
                      constant(Vow.cat(n: &is_number/1, s: &is_bitstring/1)),
                      tuple({integer(), string(:ascii)}) |> map(fn {i, s} -> [i, s, nil] end)
                    }),
                    tuple({
                      constant(Vow.maybe(&is_integer/1)),
                      list_of(string(:ascii), length: 1)
                    }),
                    tuple({
                      constant(Vow.oom(&is_integer/1)),
                      tuple(
                        {list_of(integer(), min_length: 1),
                         list_of(string(:ascii), min_length: 1)}
                      )
                      |> map(fn {xs, ys} -> xs ++ ys end)
                    }),
                    tuple({
                      constant(Vow.zom(&is_integer/1)),
                      list_of(string(:ascii), min_length: 1)
                    })
                  ]) do
        assert match?({:ok, _, [_ | _]}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "given a full match will conform and return []" do
      check all {vow, value} <-
                  one_of([
                    tuple({
                      constant(Vow.alt(n: &is_number/1, s: &is_bitstring/1)),
                      list_of(one_of([integer(), string(:ascii)]), length: 1)
                    }),
                    tuple({
                      constant(
                        Vow.amp(
                          &Enum.all?(&1, fn x -> is_number(x) end),
                          &Enum.all?(&1, fn x -> x > 42 end)
                        )
                      ),
                      list_of(integer(43..100), length: 1)
                    }),
                    tuple({
                      constant(Vow.cat(n: &is_number/1, s: &is_bitstring/1)),
                      tuple({integer(), string(:ascii)}) |> map(fn {i, s} -> [i, s] end)
                    }),
                    tuple({
                      constant(Vow.maybe(&is_integer/1)),
                      list_of(integer(), length: 1)
                    }),
                    tuple({
                      constant(Vow.oom(&is_integer/1)),
                      list_of(integer(), min_length: 1)
                    }),
                    tuple({
                      constant(Vow.zom(&is_integer/1)),
                      list_of(integer())
                    })
                  ]) do
        assert match?({:ok, _, []}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end
  end

  describe "Vow.alt/1" do
    property "should raise given an unnamed list of vows" do
      check all vows <- list_of(tuple({atom(:alphanumeric), constant(nil)}), min_length: 1),
                index <- integer(0..length(vows)),
                bad_vows = List.insert_at(vows, index, nil) do
        assert_raise(Vow.UnnamedVowsError, fn ->
          Vow.alt(bad_vows)
        end)
      end
    end

    property "should succeed on matching at least one of the given vows" do
      check all value <- list_of(one_of([integer(), float()]), min_length: 1) do
        vow = Vow.alt(i: &is_integer/1, f: &is_float/1)
        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "given multiple matching vows, will succeed on the first one to match" do
      check all value <- list_of(one_of([integer(), float()]), min_length: 1) do
        vow = Vow.alt(n: &is_number/1, i: &is_integer/1, f: &is_float/1)
        assert match?({:ok, [%{n: _}], _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "given no matching vows, should fail to conform" do
      check all value <- list_of(one_of([integer(), float()]), min_length: 1) do
        vow = Vow.alt(b: &is_boolean/1, s: &is_bitstring/1, a: &is_atom/1)
        assert match?({:error, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should throw given duplicate keys on alt declaration" do
      check all keys <- uniq_list_of(atom(:alphanumeric), min_length: 2),
                index <- integer(0..length(keys)),
                elem <- member_of(keys),
                keys = List.insert_at(keys, index, elem),
                vows = Enum.zip(keys, Stream.repeatedly(fn -> nil end)) do
        assert_raise(Vow.DuplicateNameError, fn ->
          Vow.alt(vows)
        end)
      end
    end

    property "should succeed with nested regex operators" do
      check all value <- list_of(one_of([string(:ascii), integer()]), min_length: 2) do
        vow =
          Vow.alt(
            i: &is_integer/1,
            ss: Vow.oom(&is_bitstring/1)
          )

        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end
  end

  describe "Vow.amp/1" do
    property "should succeed on matching all of the given vows" do
      check all value <- list_of(integer(1..1000), min_length: 1) do
        vow =
          Vow.amp(
            &Enum.all?(&1, fn i -> is_integer(i) end),
            &Enum.all?(&1, fn i -> i > 0 end)
          )

        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should fail given at least one vow that fails to match" do
      check all value <- list_of(integer(1..1000), min_length: 1) do
        vow =
          Vow.amp(
            &Enum.all?(&1, fn i -> is_integer(i) end),
            &Enum.all?(&1, fn i -> i < 0 end)
          )

        assert match?({:error, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should succeed given any proper list with zero vows" do
      check all value <- list_of(constant(nil)) do
        vow = Vow.amp([])
        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should succeed with nested regex operators" do
      check all booleans <- list_of(boolean(), min_length: 1),
                strings <- list_of(string(:ascii, min_length: 1), min_length: 1),
                value = strings ++ booleans do
        vow = Vow.amp(Vow.oom(&is_bitstring/1), &Enum.all?(&1, fn s -> String.length(s) > 0 end))
        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end
  end

  describe "Vow.cat/1" do
    property "should raise given an unnamed list of vows" do
      check all vows <- list_of(tuple({atom(:alphanumeric), constant(nil)}), min_length: 1),
                index <- integer(0..length(vows)),
                bad_vows = List.insert_at(vows, index, nil) do
        assert_raise(Vow.UnnamedVowsError, fn ->
          Vow.cat(bad_vows)
        end)
      end
    end

    test "if cat contains non-regex operators and given empty list -> insufficient data" do
      vow =
        Vow.cat(
          n: &is_number/1,
          i: &is_integer/1
        )

      assert match?(
               {:error, [%{reason: "Insufficient Data"}]},
               Vow.RegexOperator.conform(vow, [], [], [], [])
             )
    end

    test "if cat contains only zom/1, amp/1 & maybe/1 + empty list -> success" do
      vow =
        Vow.cat(
          m: Vow.maybe(nil),
          s: Vow.zom(nil)
        )

      assert match?({:ok, %{m: [], s: []}, []}, Vow.RegexOperator.conform(vow, [], [], [], []))
    end

    property "if cat contains non-regex and empty-list-accepting-regex -> failure" do
      vow =
        Vow.cat(
          m: Vow.maybe(nil),
          s: Vow.oom(&is_integer/1)
        )

      assert match?({:error, _}, Vow.RegexOperator.conform(vow, [], [], [], []))
    end

    property "should throw given duplicate keys on cat declaration" do
      check all keys <- uniq_list_of(atom(:alphanumeric), min_length: 2),
                index <- integer(0..length(keys)),
                elem <- member_of(keys),
                keys = List.insert_at(keys, index, elem),
                vows = Enum.zip(keys, Stream.repeatedly(fn -> nil end)) do
        assert_raise(Vow.DuplicateNameError, fn ->
          Vow.cat(vows)
        end)
      end
    end

    property "should succeed with nested regex" do
      check all value <- list_of(integer(), min_length: 2) do
        vow =
          Vow.cat(
            i: &is_integer/1,
            n: &is_number/1,
            ns: Vow.zom(&is_number/1)
          )

        assert match?(
                 {:ok, %{i: _, n: _, ns: _}, []},
                 Vow.RegexOperator.conform(vow, [], [], [], value)
               )
      end
    end
  end

  describe "Vow.maybe/1" do
    property "should succeed if given empty list" do
      check all vow <- VowData.maybe(), max_runs: 25 do
        assert match?({:ok, [], []}, Vow.RegexOperator.conform(vow, [], [], [], []))
      end
    end

    property "should succeed if given proper list" do
      check all value <- list_of(term()), max_runs: 25 do
        vow = Vow.maybe(&is_integer/1)
        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should return [head] if inner vow matches head of given value" do
      check all [h | t] = value <- list_of(integer(), min_length: 1) do
        vow = Vow.maybe(&is_integer/1)
        assert match?({:ok, [^h], ^t}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should return [] if inner vow fails to match head of given value" do
      check all value <- list_of(integer(), min_length: 1) do
        vow = Vow.maybe(&is_boolean/1)
        assert match?({:ok, [], ^value}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end
  end

  describe "Vow.oom/1" do
    property "should succeed if only 1st element/group matches" do
      check all head <- integer(),
                tail <- list_of(string(:ascii)),
                value = [head | tail] do
        vow = Vow.oom(&is_integer/1)
        assert match?({:ok, [^head], ^tail}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should fail if 1st element/group fails to match" do
      check all head <- integer(),
                tail <- list_of(float()),
                value = [head | tail] do
        vow = Vow.oom(&is_float/1)
        assert match?({:error, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end
  end

  describe "Vow.zom/1" do
    property "should succeed given proper list" do
      check all value <- list_of(string(:ascii)),
                vow <- VowData.zom(member_of([&is_integer/1, &is_bitstring/1])) do
        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should succeed given empty list" do
      check all vow <- VowData.zom(), max_runs: 25 do
        assert match?({:ok, [], []}, Vow.RegexOperator.conform(vow, [], [], [], []))
      end
    end

    property "should succeed given sub-vow that matches nothing" do
      check all value <- list_of(string(:ascii)) do
        vow = Vow.zom(&is_integer/1)
        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end

    property "should stop matching after 1st element that does not match (for non-regex sub-vow)" do
      check all matching <- list_of(string(:ascii)),
                non_matching <- list_of(float(), min_length: 1),
                value = matching ++ non_matching do
        vow = Vow.zom(&is_bitstring/1)

        assert match?(
                 {:ok, ^matching, ^non_matching},
                 Vow.RegexOperator.conform(vow, [], [], [], value)
               )
      end
    end

    property "should succeed with nested regex operator" do
      check all value <- list_of(one_of([integer(), float(), boolean()])) do
        vow = Vow.zom(Vow.alt(n: &is_number/1, b: &is_boolean/1))
        assert match?({:ok, _, _}, Vow.RegexOperator.conform(vow, [], [], [], value))
      end
    end
  end
end
