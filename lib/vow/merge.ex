defmodule Vow.Merge do
  @moduledoc false

  defstruct vows: [],
            merge_fun: nil

  @type t :: %__MODULE__{
          vows: [Vow.merged()],
          merge_fun: (term, term, term -> term)
        }

  @spec new([Vow.merged()], (key, value, value -> value) | nil) :: t
        when key: term, value: term
  def new(vows, merge_fun) do
    %__MODULE__{
      vows: vows,
      merge_fun: merge_fun
    }
  end

  defimpl Vow.Conformable do
    @moduledoc false

    alias Vow.ConformError

    def conform(%@for{vows: []}, _vow_path, _via, _value_path, value) when is_map(value) do
      {:ok, value}
    end

    def conform(%@for{vows: [vow]}, vow_path, via, value_path, value) when is_map(value) do
      @protocol.conform(vow, vow_path, via, value_path, value)
    end

    def conform(%@for{vows: [_ | _] = vows} = vow, vow_path, via, value_path, value)
        when is_map(value) do
      Enum.map(vows, fn s ->
        @protocol.conform(s, vow_path, via, value_path, value)
      end)
      |> Enum.reduce({:ok, %{}}, fn
        {:ok, conformed}, {:ok, merged} -> {:ok, merge(merged, conformed, vow.merge_fun)}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, vow_path, via, value_path, value)]}
    end

    @spec merge(map, map, (key, value, value -> value) | nil) :: map when key: term, value: term
    defp merge(map1, map2, nil), do: Map.merge(map1, map2)
    defp merge(map1, map2, merge_fun), do: Map.merge(map1, map2, merge_fun)
  end
end
