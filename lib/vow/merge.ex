defmodule Vow.Merge do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct vows: []

  @type t :: %__MODULE__{
          vows: [{atom, Vow.merged()}]
        }

  @spec new([{atom, Vow.merged()}]) :: t
  def new(vows) do
    %__MODULE__{
      vows: vows
    }
  end

  defimpl Vow.Conformable do
    @moduledoc false

    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(%@for{vows: []}, _path, _via, _route, value) when is_map(value) do
      {:ok, value}
    end

    def conform(%@for{vows: [{k, vow}]}, path, via, route, value) when is_map(value) do
      @protocol.conform(vow, [k | path], via, route, value)
    end

    def conform(%@for{vows: [_ | _] = vows}, path, via, route, value)
        when is_map(value) do
      vows
      |> Enum.map(fn {k, v} ->
        @protocol.conform(v, [k | path], via, route, value)
      end)
      |> Enum.reduce({:ok, %{}}, &conform_reducer/2)
    end

    def conform(_vow, path, via, route, value) do
      {:error, [ConformError.new_problem(&is_map/1, path, via, route, value)]}
    end

    @impl Vow.Conformable
    def unform(%@for{vows: vows}, value) when is_map(value) do
      vows
      |> Keyword.values()
      |> Enum.reverse()
      |> Enum.reduce({:ok, %{}}, fn
        _, {:error, reason} ->
          {:error, reason}

        vow, {:ok, acc} ->
          case @protocol.unform(vow, value) do
            {:ok, unformed} -> {:ok, Map.merge(acc, unformed)}
            {:error, reason} -> {:error, reason}
          end
      end)
    end

    def unform(vow, value),
      do: {:error, %Vow.UnformError{vow: vow, value: value}}

    @impl Vow.Conformable
    def regex?(_vow), do: false

    @spec conform_reducer(@protocol.result, @protocol.result) :: @protocol.result
    defp conform_reducer({:ok, conformed}, {:ok, merged}), do: {:ok, Map.merge(merged, conformed)}
    defp conform_reducer({:error, ps}, {:ok, _}), do: {:error, ps}
    defp conform_reducer({:ok, _}, {:error, ps}), do: {:error, ps}
    defp conform_reducer({:error, ps}, {:error, pblms}), do: {:error, pblms ++ ps}
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow, opts) do
        @protocol.gen(Vow.also(vow.vows), opts)
      end
    end
  end
end
