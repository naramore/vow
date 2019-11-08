defmodule Vow.ZeroOrMore do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :passthrough

  defstruct vow: nil

  @type t :: %__MODULE__{
          vow: Vow.t()
        }

  @spec new(Vow.t()) :: t
  def new(vow) do
    %__MODULE__{vow: vow}
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Acs.Improper, only: [proper_list?: 1]
    import Vow.Utils, only: [append: 2]
    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(_vow, _path, _via, _route, []) do
      {:ok, [], []}
    end

    def conform(%@for{vow: vow}, path, via, route, value)
        when is_list(value) and length(value) >= 0 do
      if Vow.regex?(vow) do
        conform_regex(vow, path, via, route, value)
      else
        conform_non_regex(vow, path, via, Utils.uninit_path(route), value)
      end
    end

    def conform(_vow, path, via, route, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           path,
           via,
           Utils.uninit_path(route),
           value
         )
       ]}
    end

    def conform(_vow, path, via, route, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           path,
           via,
           Utils.uninit_path(route),
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
            {:ok, unformed} -> {:ok, [unformed | acc]}
          end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        {:ok, unformed} -> {:ok, :lists.reverse(unformed)}
      end
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
    defp conform_regex(vow, path, via, route, rest, acc \\ [])

    defp conform_regex(_vow, _path, _via, _route, [], acc) do
      {:ok, acc, []}
    end

    defp conform_regex(vow, path, via, route, [_ | _] = rest, acc) do
      case @protocol.conform(vow, path, via, route, rest) do
        {:error, _problems} ->
          {:ok, acc, rest}

        {:ok, conformed, rest} ->
          conform_regex(
            vow,
            path,
            via,
            Utils.inc_path(route),
            rest,
            append(acc, conformed)
          )
      end
    end

    defp conform_regex(_vow, _path, _via, _route, improper, acc) do
      {:ok, acc, improper}
    end

    @spec conform_non_regex(Vow.t(), [term], [Vow.Ref.t()], [term], term, non_neg_integer, [
            term
          ]) ::
            {:ok, conformed :: term, rest :: [term]} | {:error, [ConformError.Problem.t()]}
    defp conform_non_regex(vow, path, via, route, value, pos \\ 0, acc \\ [])

    defp conform_non_regex(_vow, _path, _via, _route, [], _pos, acc) do
      {:ok, Enum.reverse(acc), []}
    end

    defp conform_non_regex(vow, path, via, route, [h | t] = value, pos, acc) do
      case Conformable.conform(vow, path, via, [pos|route], h) do
        {:error, _problems} ->
          {:ok, Enum.reverse(acc), value}

        {:ok, c} ->
          conform_non_regex(vow, path, via, route, t, pos + 1, [c | acc])
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      import Vow.Utils, only: [append: 2]

      @impl Vow.Generatable
      def gen(vow, opts) do
        case @protocol.gen(vow.vow, opts) do
          {:error, reason} ->
            {:error, reason}

          {:ok, data} ->
            if Vow.regex?(vow.vow) do
              {:ok,
               StreamData.map(
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
