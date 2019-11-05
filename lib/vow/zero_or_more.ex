defmodule Vow.ZeroOrMore do
  @moduledoc false
  @behaviour Access

  defstruct vow: nil

  @type t :: %__MODULE__{
          vow: Vow.t()
        }

  @spec new(Vow.t()) :: t
  def new(vow) do
    %__MODULE__{vow: vow}
  end

  @impl Access
  def fetch(%__MODULE__{vow: vow}, key) do
    Access.fetch(vow, key)
  end

  @impl Access
  def get_and_update(%__MODULE__{vow: vow}, key, fun) do
    Access.get_and_update(vow, key, fun)
  end

  @impl Access
  def pop(%__MODULE__{vow: vow}, key) do
    Access.pop(vow, key)
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp}

    @impl Vow.RegexOperator
    def conform(_vow, _vow_path, _via, _value_path, []) do
      {:ok, [], []}
    end

    def conform(%@for{vow: vow}, vow_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      if Vow.regex?(vow) do
        conform_regex(vow, vow_path, via, value_path, value)
      else
        conform_non_regex(vow, vow_path, via, RegexOp.uninit_path(value_path), value)
      end
    end

    def conform(_vow, vow_path, via, value_path, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           vow_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           vow_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    @impl Vow.RegexOperator
    def unform(%@for{vow: vow}, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(value, {:ok, []}, fn
        _, {:error, reason} ->
          {:error, reason}

        item, {:ok, acc} ->
          case Conformable.unform(vow, item) do
            {:error, reason} -> {:error, reason}
            {:ok, unformed} -> {:ok, acc ++ [unformed]}
          end
      end)
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
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
    defp conform_regex(vow, vow_path, via, value_path, rest, acc \\ [])

    defp conform_regex(_vow, _vow_path, _via, _value_path, [], acc) do
      {:ok, acc, []}
    end

    defp conform_regex(vow, vow_path, via, value_path, [_ | _] = rest, acc) do
      case @protocol.conform(vow, vow_path, via, value_path, rest) do
        {:error, _problems} ->
          {:ok, acc, rest}

        {:ok, conformed, rest} ->
          conform_regex(
            vow,
            vow_path,
            via,
            RegexOp.inc_path(value_path),
            rest,
            append(acc, conformed)
          )
      end
    end

    defp conform_regex(_vow, _vow_path, _via, _value_path, improper, acc) do
      {:ok, acc, improper}
    end

    @spec conform_non_regex(Vow.t(), [term], [Vow.Ref.t()], [term], term, non_neg_integer, [
            term
          ]) ::
            {:ok, conformed :: term, rest :: [term]} | {:error, [ConformError.Problem.t()]}
    defp conform_non_regex(vow, vow_path, via, value_path, value, pos \\ 0, acc \\ [])

    defp conform_non_regex(_vow, _vow_path, _via, _value_path, [], _pos, acc) do
      {:ok, Enum.reverse(acc), []}
    end

    defp conform_non_regex(vow, vow_path, via, value_path, [h | t] = value, pos, acc) do
      case Conformable.conform(vow, vow_path, via, value_path ++ [pos], h) do
        {:error, _problems} ->
          {:ok, Enum.reverse(acc), value}

        {:ok, c} ->
          conform_non_regex(vow, vow_path, via, value_path, t, pos + 1, [c | acc])
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

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      import Vow.RegexOperator.Vow.ZeroOrMore, only: [append: 2]

      @impl Vow.Generatable
      def gen(vow) do
        case @protocol.gen(vow.vow) do
          {:error, reason} -> {:error, reason}
          {:ok, data} ->
            if Vow.regex?(vow.vow) do
              {:ok, StreamData.map(
                StreamData.list_of(data),
                fn x -> Enum.reduce(x, [], &append/2) end
              )}
            else
              {:ok, StreamData.list_of(data)}
            end
        end
      end
    end
  end
end
