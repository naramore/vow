defmodule Vow.Alt do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct [:vows]

  @type t :: %__MODULE__{
          vows: [{atom, Vow.t()}, ...]
        }

  @spec new([Vow.t()]) :: t
  def new(named_vows) do
    vow = %__MODULE__{vows: named_vows}

    if Vow.Cat.unique_keys?(named_vows) do
      vow
    else
      raise %Vow.DuplicateNameError{vow: vow}
    end
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    alias Vow.Conformable

    @impl Vow.RegexOperator
    def conform(%@for{vows: vows}, path, via, route, val) do
      Enum.reduce(
        vows,
        {:error, []},
        &reducer(&1, &2, path, via, route, val)
      )
    end

    @impl Vow.RegexOperator
    def unform(%@for{vows: vows} = vow, val) when is_map(val) do
      with [key] <- Map.keys(val),
           true <- Keyword.has_key?(vows, key) do
        Conformable.unform(Keyword.get(vows, key), Map.get(val, key))
      else
        _ -> {:error, %Vow.UnformError{vow: vow, val: val}}
      end
    end

    def unform(vow, val) do
      {:error, %Vow.UnformError{vow: vow, val: val}}
    end

    @spec reducer({atom, Vow.t()}, result, [term], [Vow.Ref.t()], [term], term) :: result
          when result: {:ok, @protocol.conformed, @protocol.rest} | {:error, reason :: term}
    defp reducer(_, {:ok, conformed, rest}, _, _, _, _) do
      {:ok, conformed, rest}
    end

    defp reducer({k, v}, {:error, pblms}, path, via, route, val) do
      case @protocol.conform(v, [k | path], via, route, val) do
        {:error, problems} -> {:error, pblms ++ problems}
        {:ok, conformed, rest} -> {:ok, [%{k => conformed}], rest}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow, opts) do
        @protocol.Vow.OneOf.gen(Vow.one_of(vow.vows), opts)
      end
    end
  end
end
