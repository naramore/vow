defmodule Vow.Also do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct vows: []

  @type t :: %__MODULE__{
          vows: [{atom, Vow.t()}]
        }

  @spec new([{atom, Vow.t()}]) :: t
  def new(vows) do
    %__MODULE__{vows: vows}
  end

  defimpl Vow.Conformable do
    @moduledoc false

    @impl Vow.Conformable
    def conform(%@for{vows: []}, _path, _via, _route, value) do
      {:ok, value}
    end

    def conform(%@for{vows: [{k, vow}]}, path, via, route, value) do
      @protocol.conform(vow, [k | path], via, route, value)
    end

    def conform(%@for{vows: vows}, path, via, route, value) when is_list(vows) do
      Enum.reduce(vows, {:ok, value}, fn
        _, {:error, pblms} ->
          {:error, pblms}

        {k, v}, {:ok, c} ->
          @protocol.conform(v, [k | path], via, route, c)
      end)
    end

    @impl Vow.Conformable
    def unform(%@for{vows: vows}, value) do
      vows
      |> Keyword.values()
      |> Enum.reverse()
      |> Enum.reduce({:ok, value}, fn
        _, {:error, reason} ->
          {:error, reason}

        vow, {:ok, unformed} ->
          @protocol.unform(vow, unformed)
      end)
    end

    @impl Vow.Conformable
    def regex?(_vow), do: false
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      alias Vow.Utils

      @impl Vow.Generatable
      def gen(vow, opts) do
        vow.vows
        |> Keyword.values()
        |> Enum.reduce({:ok, []}, &reducer(&1, &2, opts))
        |> to_one_of(vow, opts)
      end

      @spec reducer(Vow.t(), @protocol.result, keyword) :: @protocol.result
      defp reducer(_, {:error, reason}, _opts) do
        {:error, reason}
      end

      defp reducer(vow, {:ok, acc}, opts) do
        case @protocol.gen(vow, opts) do
          {:error, reason} -> {:error, reason}
          {:ok, data} -> {:ok, [data | acc]}
        end
      end

      @spec to_one_of(@protocol.result, Vow.t(), keyword) :: @protocol.result
      defp to_one_of({:error, reason}, _vow, _opts) do
        {:error, reason}
      end

      defp to_one_of({:ok, datas}, vow, opts) do
        ignore_warn? = Keyword.get(opts, :ignore_warn?, false)
        _ = Utils.no_override_warn(vow, ignore_warn?)
        {:ok, to_one_of(Enum.reverse(datas), vow)}
      end

      @spec to_one_of([@protocol.generator], Vow.t()) :: @protocol.generator
      defp to_one_of(datas, vow) do
        datas
        |> StreamData.one_of()
        |> StreamData.filter(&Vow.valid?(vow, &1))
      end
    end
  end
end
