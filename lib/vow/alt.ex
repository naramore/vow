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
    def conform(%@for{vows: vows}, path, via, route, value) do
      Enum.reduce(
        vows,
        {:error, []},
        &reducer(&1, &2, path, via, route, value)
      )
    end

    @impl Vow.RegexOperator
    def unform(%@for{vows: vows} = vow, value) when is_map(value) do
      with [key] <- Map.keys(value),
           true <- Keyword.has_key?(vows, key) do
        Conformable.unform(Keyword.get(vows, key), Map.get(value, key))
      else
        _ -> {:error, %Vow.UnformError{vow: vow, value: value}}
      end
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end

    @spec reducer({atom, Vow.t()}, result, [term], [Vow.Ref.t()], [term], term) :: result
          when result: {:ok, @protocol.conformed, @protocol.rest} | {:error, reason :: term}
    defp reducer(_, {:ok, conformed, rest}, _, _, _, _) do
      {:ok, conformed, rest}
    end

    defp reducer({k, v}, {:error, pblms}, path, via, route, value) do
      case @protocol.conform(v, [k | path], via, route, value) do
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
