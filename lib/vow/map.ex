defmodule Vow.Map do
  @moduledoc false

  defstruct key_vow: nil,
            value_vow: nil,
            min_length: 0,
            max_length: nil,
            conform_keys?: false

  @type t :: %__MODULE__{
          key_vow: Vow.t(),
          value_vow: Vow.t(),
          min_length: non_neg_integer,
          max_length: non_neg_integer | nil,
          conform_keys?: boolean
        }

  @spec new(Vow.t(), Vow.t(), non_neg_integer, non_neg_integer | nil, boolean) :: t
  def new(
        key_vow,
        value_vow,
        min_length,
        max_length,
        conform_keys?
      ) do
    %__MODULE__{
      key_vow: key_vow,
      value_vow: value_vow,
      min_length: min_length,
      max_length: max_length,
      conform_keys?: conform_keys?
    }
  end

  defimpl Vow.Conformable do
    @moduledoc false

    import Vow.FunctionWrapper, only: [wrap: 1]
    alias Vow.ConformError

    def conform(vow, vow_path, via, value_path, value) when is_map(value) do
      value
      |> Enum.map(fn {k, v} ->
        conform_key_value(vow, vow_path, via, value_path, {k, v})
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, c}, {:ok, cs} -> {:ok, [c | cs]}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
      |> ConformError.add_problems(size_problems(vow, vow_path, via, value_path, value), true)
      |> case do
        {:ok, conformed} -> {:ok, Enum.into(conformed, %{})}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, vow_path, via, value_path, value)]}
    end

    @spec conform_key_value(@for.t, [term], [Vow.Ref.t()], [term], {term, term}) ::
            {:ok, term} | {:error, [ConformError.Problem.t()]}
    defp conform_key_value(
           %@for{conform_keys?: conform_keys?} = vow,
           vow_path,
           via,
           value_path,
           {k, v}
         ) do
      {
        @protocol.conform(vow.key_vow, vow_path, via, value_path, k),
        @protocol.conform(vow.value_vow, vow_path, via, value_path ++ [k], v)
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
    defp size_problems(vow, vow_path, via, value_path, value) do
      case {vow.min_length, vow.max_length} do
        {min, _max} when map_size(value) < min ->
          [
            ConformError.new_problem(
              wrap(&(map_size(&1) >= min)),
              vow_path,
              via,
              value_path,
              value
            )
          ]

        {_min, max} when not is_nil(max) and map_size(value) > max ->
          [
            ConformError.new_problem(
              wrap(&(map_size(&1) <= max)),
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
  end
end
