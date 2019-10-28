defmodule Vow.ZeroOrMore do
  @moduledoc false

  defstruct spec: nil

  @type t :: %__MODULE__{
          spec: Vow.t()
        }

  @spec new(Vow.t()) :: t
  def new(spec) do
    %__MODULE__{spec: spec}
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp}

    def conform(_spec, _spec_path, _via, _value_path, []) do
      {:ok, [], []}
    end

    def conform(%@for{spec: spec}, spec_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      if Vow.regex?(spec) do
        conform_regex(spec, spec_path, via, value_path, value)
      else
        conform_non_regex(spec, spec_path, via, RegexOp.uninit_path(value_path), value)
      end
    end

    def conform(_spec, spec_path, via, value_path, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           spec_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           spec_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    @spec conform_regex(
            Vow.t(),
            [term],
            [Vow.Ref.t()],
            [term],
            maybe_improper_list(term, term) | term,
            [term]
          ) ::
            {:ok, conformed :: term, rest :: term}
    defp conform_regex(spec, spec_path, via, value_path, rest, acc \\ [])

    defp conform_regex(_spec, _spec_path, _via, _value_path, [], acc) do
      {:ok, acc, []}
    end

    defp conform_regex(spec, spec_path, via, value_path, [_ | _] = rest, acc) do
      case @protocol.conform(spec, spec_path, via, value_path, rest) do
        {:error, _problems} ->
          {:ok, acc, rest}

        {:ok, conformed, rest} ->
          conform_regex(
            spec,
            spec_path,
            via,
            RegexOp.inc_path(value_path),
            rest,
            append(acc, conformed)
          )
      end
    end

    defp conform_regex(_spec, _spec_path, _via, _value_path, improper, acc) do
      {:ok, acc, improper}
    end

    @spec conform_non_regex(Vow.t(), [term], [Vow.Ref.t()], [term], term, non_neg_integer, [
            term
          ]) ::
            {:ok, conformed :: term, rest :: [term]} | {:error, [ConformError.Problem.t()]}
    defp conform_non_regex(spec, spec_path, via, value_path, value, pos \\ 0, acc \\ [])

    defp conform_non_regex(_spec, _spec_path, _via, _value_path, [], _pos, acc) do
      {:ok, Enum.reverse(acc), []}
    end

    defp conform_non_regex(spec, spec_path, via, value_path, [h | t] = value, pos, acc) do
      case Conformable.conform(spec, spec_path, via, value_path ++ [pos], h) do
        {:error, _problems} ->
          {:ok, Enum.reverse(acc), value}

        {:ok, c} ->
          conform_non_regex(spec, spec_path, via, value_path, t, pos + 1, [c | acc])
      end
    end

    @spec append(list | term, list | term) :: list
    def append([], []), do: []
    def append([_ | _] = l, []), do: l
    def append([], [_ | _] = r), do: r
    def append([_ | _] = l, [_ | _] = r), do: l ++ r
    def append(l, r) when is_list(r), do: [l | r]
    def append(l, r) when is_list(l), do: l ++ [r]
  end
end
