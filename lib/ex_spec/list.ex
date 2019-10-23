defmodule ExSpec.List do
  @moduledoc false

  defstruct spec: nil,
            min_length: 0,
            max_length: nil,
            distinct?: false

  @type t :: %__MODULE__{
          spec: ExSpec.t(),
          min_length: non_neg_integer,
          max_length: non_neg_integer | nil,
          distinct?: boolean
        }

  @spec new(ExSpec.t(), non_neg_integer, non_neg_integer | nil, boolean) :: t
  def new(spec, min_length \\ 0, max_length \\ nil, distinct? \\ false) do
    %__MODULE__{
      spec: spec,
      min_length: min_length,
      max_length: max_length,
      distinct?: distinct?
    }
  end

  defimpl ExSpec.Conformable do
    @moduledoc false

    use ExSpec.Func
    alias ExSpec.ConformError

    def conform(spec, spec_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      value
      |> Enum.with_index()
      |> Enum.map(fn {e, i} ->
        @protocol.conform(spec.spec, spec_path, via, value_path ++ [i], e)
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, c}, {:ok, cs} -> {:ok, [c | cs]}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
      |> ConformError.add_problems(length_problems(spec, spec_path, via, value_path, value), true)
      |> ConformError.add_problems(
        distinct_problems(spec, spec_path, via, value_path, value),
        true
      )
      |> case do
        {:ok, conformed} -> {:ok, Enum.reverse(conformed)}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_spec, spec_path, via, value_path, value)
        when is_list(value) do
      {:error, [ConformError.new_problem(&proper_list?/1, spec_path, via, value_path, value)]}
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_list/1, spec_path, via, value_path, value)]}
    end

    @spec distinct_problems(ExSpec.t(), [term], [ExSpec.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    def distinct_problems(spec, spec_path, via, value_path, value) do
      if spec.distinct? and not distinct?(value) do
        [ConformError.new_problem(&distinct?/1, spec_path, via, value_path, value)]
      else
        []
      end
    end

    @spec length_problems(@for.t, [term], [ExSpec.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    defp length_problems(spec, spec_path, via, value_path, value) do
      case {value, spec.min_length, spec.max_length} do
        {list, min, nil} when length(list) < min ->
          [ConformError.new_problem(f(&(length(&1) >= min)), spec_path, via, value_path, value)]

        {_list, _min, nil} ->
          []

        {list, min, max} when length(list) < min and length(list) > max ->
          [
            ConformError.new_problem(f(&(length(&1) >= min)), spec_path, via, value_path, value),
            ConformError.new_problem(f(&(length(&1) <= max)), spec_path, via, value_path, value)
          ]

        {list, min, _max} when length(list) < min ->
          [ConformError.new_problem(f(&(length(&1) >= min)), spec_path, via, value_path, value)]

        {list, _min, max} when length(list) > max ->
          [ConformError.new_problem(f(&(length(&1) <= max)), spec_path, via, value_path, value)]

        _ ->
          []
      end
    end

    @spec proper_list?(term) :: boolean
    def proper_list?([]), do: true
    def proper_list?([_ | t]) when is_list(t), do: proper_list?(t)
    def proper_list?(_), do: false

    @spec distinct?(Enum.t()) :: boolean
    def distinct?(enum) do
      count = enum |> Enum.count()
      unique_count = enum |> Enum.uniq() |> Enum.count()
      count == unique_count
    end
  end
end
