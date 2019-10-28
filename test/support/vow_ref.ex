defmodule VowRef do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias StreamData, as: SD

  def one_arity(_), do: nil
  def two_arity(_, _), do: nil
  def three_arity(_, _, _), do: nil
  def four_arity(_, _, _, _), do: nil

  def raise!, do: raise(%RuntimeError{})
  def throw!, do: throw(:throw)
  def exit_normal!, do: exit(:normal)
  def exit_abnormal!, do: exit(:abnormal)

  def any, do: fn _ -> true end
  def none, do: fn _ -> false end
  def map_spec, do: Vow.map_of(&is_atom/1, &is_bitstring/1)

  def clj_spec do
    Vow.oom(
      Vow.alt(
        n: &is_number/1,
        s:
          Vow.also([
            Vow.oom(&is_bitstring/1),
            wrap(&Enum.all?(&1, fn s -> String.length(s) > 0 end))
          ])
      )
    )
  end

  def clj_spec_gen do
    SD.list_of(
      SD.one_of([
        SD.one_of([SD.integer(), SD.float()]),
        SD.list_of(SD.string([?a..?z], min_length: 1), min_length: 1)
      ]),
      min_length: 1
    )
  end

  def clj_regexop do
    Vow.oom(
      Vow.alt(
        n: &is_number/1,
        s:
          Vow.amp([
            Vow.oom(&is_bitstring/1),
            wrap(&Enum.all?(&1, fn s -> String.length(s) > 0 end))
          ])
      )
    )
  end

  def clj_regexop_gen do
    SD.list_of(
      SD.one_of([
        SD.one_of([SD.integer(), SD.float()]),
        SD.string([?a..?z], min_length: 1)
      ]),
      min_length: 1
    )
  end
end
