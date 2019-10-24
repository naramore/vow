defmodule Vow.Merge do
  @moduledoc false

  defstruct specs: [],
            merge_fun: nil

  @type t :: %__MODULE__{
          specs: [Vow.merged()],
          merge_fun: (term, term, term -> term)
        }

  @spec new([Vow.merged()], (key, value, value -> value) | nil) :: t
        when key: term, value: term
  def new(specs, merge_fun \\ nil) do
    %__MODULE__{
      specs: specs,
      merge_fun: merge_fun
    }
  end

  defimpl Vow.Conformable do
    @moduledoc false

    alias Vow.ConformError

    def conform(%@for{specs: []}, _spec_path, _via, _value_path, value) when is_map(value) do
      {:ok, value}
    end

    def conform(%@for{specs: [spec]}, spec_path, via, value_path, value) when is_map(value) do
      @protocol.conform(spec, spec_path, via, value_path, value)
    end

    def conform(%@for{specs: [_ | _] = specs} = spec, spec_path, via, value_path, value)
        when is_map(value) do
      # NOTE: pretty sure this doesn't work how I think it does...I should look into it...
      Enum.map(specs, fn s ->
        @protocol.conform(s, spec_path, via, value_path, value)
      end)
      |> Enum.reduce({:ok, %{}}, fn
        {:ok, conformed}, {:ok, merged} -> {:ok, merge(merged, conformed, spec.merge_fun)}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, spec_path, via, value_path, value)]}
    end

    @spec merge(map, map, (key, value, value -> value) | nil) :: map when key: term, value: term
    defp merge(map1, map2, nil), do: Map.merge(map1, map2)
    defp merge(map1, map2, merge_fun), do: Map.merge(map1, map2, merge_fun)
  end
end
