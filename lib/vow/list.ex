defmodule Vow.List do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :passthrough

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

    import Vow.FunctionWrapper
    import Acs.Improper, only: [proper_list?: 1]
    import Vow.Utils, only: [distinct?: 1]
    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(vow, path, via, route, value)
        when is_list(value) and length(value) >= 0 do
      value
      |> Enum.with_index()
      |> Enum.map(fn {e, i} ->
        @protocol.conform(vow.vow, path, via, [i|route], e)
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, c}, {:ok, cs} -> {:ok, [c | cs]}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
      |> ConformError.add_problems(length_problems(vow, path, via, route, value), true)
      |> ConformError.add_problems(
        distinct_problems(vow, path, via, route, value),
        true
      )
      |> case do
        {:ok, conformed} -> {:ok, Enum.reverse(conformed)}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_vow, path, via, route, value)
        when is_list(value) do
      {:error, [ConformError.new_problem(&proper_list?/1, path, via, route, value)]}
    end

    def conform(_vow, path, via, route, value) do
      {:error, [ConformError.new_problem(&is_list/1, path, via, route, value)]}
    end

    @impl Vow.Conformable
    def unform(%@for{vow: vow}, value) when is_list(value) do
      Enum.reduce(value, {:ok, []}, fn
        _, {:error, reason} ->
          {:error, reason}

        item, {:ok, acc} ->
          case @protocol.unform(vow, item) do
            {:error, reason} -> {:error, reason}
            {:ok, unformed} -> {:ok, [unformed | acc]}
          end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        {:ok, unformed} -> {:ok, :lists.reverse(unformed)}
      end
    end

    def unform(vow, value),
      do: {:error, %Vow.UnformError{vow: vow, value: value}}

    @spec distinct_problems(Vow.t(), [term], [Vow.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    def distinct_problems(vow, path, via, route, value) do
      if vow.distinct? and not distinct?(value) do
        [ConformError.new_problem(&distinct?/1, path, via, route, value)]
      else
        []
      end
    end

    @spec length_problems(@for.t, [term], [Vow.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    defp length_problems(vow, path, via, route, value) do
      case {vow.min_length, vow.max_length} do
        {min, _max} when length(value) < min ->
          [
            ConformError.new_problem(
              wrap(&(length(&1) >= min), min: min),
              path,
              via,
              route,
              value
            )
          ]

        {_min, max} when not is_nil(max) and length(value) > max ->
          [
            ConformError.new_problem(
              wrap(&(length(&1) <= max), max: max),
              path,
              via,
              route,
              value
            )
          ]

        _ ->
          []
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow, opts) do
        with {:ok, item_gen} <- @protocol.gen(vow.vow, opts),
             {opts, _} <- Map.from_struct(vow) |> Map.split([:min_length, :max_length]),
             {false, _, _} <- {vow.distinct?, item_gen, opts} do
          {:ok, StreamData.list_of(item_gen, Enum.into(opts, []))}
        else
          {:error, reason} ->
            {:error, reason}

          {true, gen, opts} ->
            {:ok, StreamData.uniq_list_of(gen, Enum.into(opts, []))}
        end
      end
    end
  end
end
