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
    def conform(%@for{vows: []}, _vow_path, _via, _value_path, value) when is_map(value) do
      {:ok, value}
    end

    def conform(%@for{vows: [{k, vow}]}, vow_path, via, value_path, value) when is_map(value) do
      @protocol.conform(vow, vow_path ++ [k], via, value_path, value)
    end

    def conform(%@for{vows: [_ | _] = vows}, vow_path, via, value_path, value)
        when is_map(value) do
      Enum.map(vows, fn {k, v} ->
        @protocol.conform(v, vow_path ++ [k], via, value_path, value)
      end)
      |> Enum.reduce({:ok, %{}}, fn
        {:ok, conformed}, {:ok, merged} -> {:ok, Map.merge(merged, conformed)}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, vow_path, via, value_path, value)]}
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
