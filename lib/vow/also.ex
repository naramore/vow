defmodule Vow.Also do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :many_passthrough

  defstruct vows: []

  @type t :: %__MODULE__{
          vows: [Vow.t()]
        }

  @spec new([Vow.t()]) :: t
  def new(vows) do
    %__MODULE__{vows: vows}
  end

  defimpl Vow.Conformable do
    @moduledoc false

    @impl Vow.Conformable
    def conform(%@for{vows: []}, _vow_path, _via, _value_path, value) do
      {:ok, value}
    end

    def conform(%@for{vows: [vow]}, vow_path, via, value_path, value) do
      @protocol.conform(vow, vow_path, via, value_path, value)
    end

    def conform(%@for{vows: vows}, vow_path, via, value_path, value) when is_list(vows) do
      Enum.reduce(vows, {:ok, value}, fn
        _, {:error, pblms} ->
          {:error, pblms}

        s, {:ok, c} ->
          @protocol.conform(s, vow_path, via, value_path, c)
      end)
    end

    @impl Vow.Conformable
    def unform(%@for{vows: vows}, value) do
      vows
      |> Enum.reverse()
      |> Enum.reduce({:ok, value}, fn
        _, {:error, reason} ->
          {:error, reason}

        vow, {:ok, unformed} ->
          @protocol.unform(vow, unformed)
      end)
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      alias Vow.Utils

      @impl Vow.Generatable
      def gen(vow, opts) do
        Enum.reduce(vow.vows, {:ok, []}, fn
          _, {:error, reason} ->
            {:error, reason}

          v, {:ok, acc} ->
            case @protocol.gen(v, opts) do
              {:error, reason} -> {:error, reason}
              {:ok, data} -> {:ok, [data | acc]}
            end
        end)
        |> case do
          {:error, reason} ->
            {:error, reason}

          {:ok, datas} ->
            ignore_warn? = Keyword.get(opts, :ignore_warn?, false)
            _ = Utils.no_override_warn(vow, ignore_warn?)

            datas
            |> Enum.reverse()
            |> StreamData.one_of()
            |> StreamData.filter(&Vow.valid?(vow, &1))
            |> (&{:ok, &1}).()
        end
      end
    end
  end
end
