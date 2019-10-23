defmodule ExSpec.Map do
  @moduledoc false

  defstruct key_spec: nil,
            value_spec: nil,
            min_length: 0,
            max_length: nil,
            distinct?: false,
            conform_keys?: false

  @type t :: %__MODULE__{
          key_spec: ExSpec.t(),
          value_spec: ExSpec.t(),
          min_length: non_neg_integer,
          max_length: non_neg_integer | nil,
          distinct?: boolean,
          conform_keys?: boolean
        }

  @spec new(ExSpec.t(), ExSpec.t(), non_neg_integer, non_neg_integer | nil, boolean, boolean) :: t
  def new(
        key_spec,
        value_spec,
        min_length \\ 0,
        max_length \\ nil,
        distinct? \\ false,
        conform_keys? \\ false
      ) do
    %__MODULE__{
      key_spec: key_spec,
      value_spec: value_spec,
      min_length: min_length,
      max_length: max_length,
      distinct?: distinct?,
      conform_keys?: conform_keys?
    }
  end

  defimpl ExSpec.Conformable do
    @moduledoc false

    use ExSpec.Func
    import ExSpec.Conformable.ExSpec.List, only: [distinct_problems: 5]
    alias ExSpec.ConformError

    def conform(spec, spec_path, via, value_path, value) when is_map(value) do
      value
      |> Enum.map(fn {k, v} ->
        conform_key_value(spec.value_spec, spec_path, via, value_path, {k, v})
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, c}, {:ok, cs} -> {:ok, [c | cs]}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
      |> ConformError.add_problems(size_problems(spec, spec_path, via, value_path, value), true)
      |> ConformError.add_problems(
        distinct_problems(spec, spec_path, via, value_path, value),
        true
      )
      |> case do
        {:ok, conformed} -> {:ok, Enum.into(conformed, %{})}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, spec_path, via, value_path, value)]}
    end

    @spec conform_key_value(@for.t, [term], [ExSpec.Ref.t()], [term], {term, term}) ::
            {:ok, term} | {:error, [ConformError.Problem.t()]}
    defp conform_key_value(
           %@for{conform_keys?: conform_keys?} = spec,
           spec_path,
           via,
           value_path,
           {k, v}
         ) do
      {
        @protocol.conform(spec.key_spec, spec_path, via, value_path, k),
        @protocol.conform(spec.value_spec, spec_path, via, value_path ++ [k], v)
      }
      |> case do
        {{:ok, ck}, {:ok, cv}} ->
          {:ok, {if(conform_keys?, do: ck, else: k), cv}}

        {{:error, kps}, {:error, vps}} ->
          {:error, vps ++ kps}

        {_, {:error, vps}} ->
          {:error, vps}

        {{:error, kps}, _} ->
          {:error, kps}
      end
    end

    @spec size_problems(@for.t, [term], [ExSpec.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    defp size_problems(spec, spec_path, via, value_path, value) do
      case {value, spec.min_length, spec.max_length} do
        {map, min, nil} when map_size(map) < min ->
          [ConformError.new_problem(f(&(map_size(&1) >= min)), spec_path, via, value_path, value)]

        {_map, _min, nil} ->
          []

        {map, min, max} when map_size(map) < min and map_size(map) > max ->
          [
            ConformError.new_problem(
              f(&(map_size(&1) >= min)),
              spec_path,
              via,
              value_path,
              value
            ),
            ConformError.new_problem(f(&(map_size(&1) <= max)), spec_path, via, value_path, value)
          ]

        {map, min, _max} when map_size(map) < min ->
          [ConformError.new_problem(f(&(map_size(&1) >= min)), spec_path, via, value_path, value)]

        {map, _min, max} when map_size(map) > max ->
          [ConformError.new_problem(f(&(map_size(&1) <= max)), spec_path, via, value_path, value)]

        _ ->
          []
      end
    end
  end
end
