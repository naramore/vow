defmodule Vow.Cat do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct [:vows]

  @type t :: %__MODULE__{
          vows: [{atom, Vow.t()}, ...]
        }

  @spec new([{atom, Vow.t()}, ...]) :: t | no_return
  def new(named_vows) do
    vow = %__MODULE__{vows: named_vows}

    if unique_keys?(named_vows) do
      vow
    else
      raise %Vow.DuplicateNameError{vow: vow}
    end
  end

  @spec unique_keys?([{atom, Vow.t()}]) :: boolean | no_return
  def unique_keys?(named_vows) do
    if Enum.all?(named_vows, &match?({name, _} when is_atom(name), &1)) do
      {keys, _} = Enum.unzip(named_vows)
      unique_keys = Enum.uniq(keys)
      length(keys) == length(unique_keys)
    else
      raise %Vow.UnnamedVowsError{vows: named_vows}
    end
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    alias Vow.{Conformable, ConformError, RegexOperator, Utils}

    @type result ::
            {:ok, RegexOperator.conformed(), RegexOperator.rest()}
            | {:error, [ConformError.Problem.t()]}

    @impl Vow.RegexOperator
    def conform(%@for{vows: vows}, path, via, route, val) do
      Enum.reduce(
        vows,
        {:ok, %{}, val},
        &conform_reducer(path, via, route, &1, &2)
      )
    end

    @impl Vow.RegexOperator
    def unform(%@for{vows: vows} = vow, val) when is_map(val) do
      Enum.reduce(vows, {:ok, []}, fn
        _, {:error, reason} ->
          {:error, reason}

        {k, v}, {:ok, acc} ->
          if Map.has_key?(val, k) do
            case Conformable.unform(v, Map.get(val, k)) do
              {:error, reason} -> {:error, reason}
              {:ok, unformed} -> {:ok, Utils.append(acc, unformed)}
            end
          else
            {:error, %Vow.UnformError{vow: vow, val: val}}
          end
      end)
    end

    def unform(vow, val) do
      {:error, %Vow.UnformError{vow: vow, val: val}}
    end

    @spec conform_reducer(
            [term],
            [Vow.Ref.t()],
            [term],
            {atom, Vow.t()},
            result
          ) :: result
    defp conform_reducer(_, _, _, _, {:error, pblms}) do
      {:error, pblms}
    end

    defp conform_reducer(path, via, route, {k, v}, {:ok, acc, rest}) do
      case @protocol.conform(v, path, via, route, rest) do
        {:error, problems} -> {:error, problems}
        {:ok, c, r} -> {:ok, Map.put(acc, k, c), r}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      import Vow.Utils, only: [append: 2]
      import StreamData

      @impl Vow.Generatable
      def gen(vow, opts) do
        vow.vows
        |> Enum.reduce({:ok, []}, &reducer(&1, &2, opts))
        |> to_list()
      end

      @spec reducer({atom, Vow.t()}, @protocol.result, keyword) :: @protocol.result
      defp reducer(_, {:error, reason}, _opts) do
        {:error, reason}
      end

      defp reducer({_, vow}, {:ok, acc}, opts) do
        case @protocol.gen(vow, opts) do
          {:error, reason} -> {:error, reason}
          {:ok, data} -> {:ok, [tuple({constant(Vow.regex?(vow)), data}) | acc]}
        end
      end

      @spec to_list(@protocol.result) :: @protocol.result
      defp to_list({:error, reason}) do
        {:error, reason}
      end

      defp to_list({:ok, datas}) do
        generator =
          datas
          |> :lists.reverse()
          |> fixed_list()
          |> map(fn elems ->
            elems
            |> Enum.reduce([], &to_list_reducer/2)
            |> :lists.reverse()
          end)

        {:ok, generator}
      end

      @spec to_list_reducer({boolean, @protocol.generator}, [@protocol.generator]) :: [
              @protocol.generator
            ]
      defp to_list_reducer({true, elem}, acc), do: append(elem, acc)
      defp to_list_reducer({false, elem}, acc), do: [elem | acc]
    end
  end
end
