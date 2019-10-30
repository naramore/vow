defmodule Vow.List do
  @moduledoc false

  defstruct vow: nil,
            min_length: 0,
            max_length: nil,
            distinct?: false

  @type t :: %__MODULE__{
          vow: Vow.t(),
          min_length: non_neg_integer,
          max_length: non_neg_integer | nil,
          distinct?: boolean
        }

  @spec new(Vow.t(), non_neg_integer, non_neg_integer | nil, boolean) :: t
  def new(vow, min_length, max_length, distinct?) do
    %__MODULE__{
      vow: vow,
      min_length: min_length,
      max_length: max_length,
      distinct?: distinct?
    }
  end

  defimpl Vow.Conformable do
    @moduledoc false

    import Vow.FunctionWrapper, only: [wrap: 1]
    alias Vow.ConformError

    def conform(vow, vow_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      value
      |> Enum.with_index()
      |> Enum.map(fn {e, i} ->
        @protocol.conform(vow.vow, vow_path, via, value_path ++ [i], e)
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, c}, {:ok, cs} -> {:ok, [c | cs]}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
      |> ConformError.add_problems(length_problems(vow, vow_path, via, value_path, value), true)
      |> ConformError.add_problems(
        distinct_problems(vow, vow_path, via, value_path, value),
        true
      )
      |> case do
        {:ok, conformed} -> {:ok, Enum.reverse(conformed)}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_vow, vow_path, via, value_path, value)
        when is_list(value) do
      {:error, [ConformError.new_problem(&proper_list?/1, vow_path, via, value_path, value)]}
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_list/1, vow_path, via, value_path, value)]}
    end

    @spec distinct_problems(Vow.t(), [term], [Vow.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    def distinct_problems(vow, vow_path, via, value_path, value) do
      if vow.distinct? and not distinct?(value) do
        [ConformError.new_problem(&distinct?/1, vow_path, via, value_path, value)]
      else
        []
      end
    end

    @spec length_problems(@for.t, [term], [Vow.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    defp length_problems(vow, vow_path, via, value_path, value) do
      case {vow.min_length, vow.max_length} do
        {min, _max} when length(value) < min ->
          [
            ConformError.new_problem(
              wrap(&(length(&1) >= min)),
              vow_path,
              via,
              value_path,
              value
            )
          ]

        {_min, max} when not is_nil(max) and length(value) > max ->
          [
            ConformError.new_problem(
              wrap(&(length(&1) <= max)),
              vow_path,
              via,
              value_path,
              value
            )
          ]

        _ ->
          []
      end
    end

    # NOTE: only used as a predicate indirectly from problem creation
    # coveralls-ignore-start
    @spec proper_list?(term) :: boolean
    def proper_list?([]), do: true
    def proper_list?([_ | t]) when is_list(t), do: proper_list?(t)
    def proper_list?(_), do: false
    # coveralls-ignore-stop

    @spec distinct?(Enum.t()) :: boolean
    def distinct?(enum) do
      count = enum |> Enum.count()
      unique_count = enum |> Enum.uniq() |> Enum.count()
      count == unique_count
    end
  end
end
