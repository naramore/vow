defmodule Vow.Map do
  @moduledoc false

  defstruct key_spec: nil,
            value_spec: nil,
            min_length: 0,
            max_length: nil,
            conform_keys?: false

  @type t :: %__MODULE__{
          key_spec: Vow.t(),
          value_spec: Vow.t(),
          min_length: non_neg_integer,
          max_length: non_neg_integer | nil,
          conform_keys?: boolean
        }

  @spec new(Vow.t(), Vow.t(), non_neg_integer, non_neg_integer | nil, boolean) :: t
  def new(
        key_spec,
        value_spec,
        min_length,
        max_length,
        conform_keys?
      ) do
    %__MODULE__{
      key_spec: key_spec,
      value_spec: value_spec,
      min_length: min_length,
      max_length: max_length,
      conform_keys?: conform_keys?
    }
  end

  defimpl Vow.Conformable do
    @moduledoc false

    import Vow.FunctionWrapper, only: [wrap: 1]
    alias Vow.ConformError

    def conform(spec, spec_path, via, value_path, value) when is_map(value) do
      value
      |> Enum.map(fn {k, v} ->
        conform_key_value(spec, spec_path, via, value_path, {k, v})
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, c}, {:ok, cs} -> {:ok, [c | cs]}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
      |> ConformError.add_problems(size_problems(spec, spec_path, via, value_path, value), true)
      |> case do
        {:ok, conformed} -> {:ok, Enum.into(conformed, %{})}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, spec_path, via, value_path, value)]}
    end

    @spec conform_key_value(@for.t, [term], [Vow.Ref.t()], [term], {term, term}) ::
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

    @spec size_problems(@for.t, [term], [Vow.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    defp size_problems(spec, spec_path, via, value_path, value) do
      case {spec.min_length, spec.max_length} do
        {min, _max} when map_size(value) < min ->
          [
            ConformError.new_problem(
              wrap(&(map_size(&1) >= min)),
              spec_path,
              via,
              value_path,
              value
            )
          ]

        {_min, max} when not is_nil(max) and map_size(value) > max ->
          [
            ConformError.new_problem(
              wrap(&(map_size(&1) <= max)),
              spec_path,
              via,
              value_path,
              value
            )
          ]

        _ ->
          []
      end
    end
  end
end
