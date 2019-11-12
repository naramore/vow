defmodule Vow.Amp do
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

  defimpl Vow.RegexOperator do
    @moduledoc false

    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(%@for{vows: []}, _path, _via, _route, val) do
      {:ok, val, []}
    end

    def conform(%@for{vows: vows}, path, via, route, val) do
      Enum.reduce(vows, {:ok, val, []}, fn
        _, {:error, pblms} ->
          {:error, pblms}

        {k, v}, {:ok, c, rest} ->
          case conform_impl(v, [k | path], via, route, c) do
            {:ok, conformed, tail} -> {:ok, conformed, tail ++ rest}
            {:error, problems} -> {:error, problems}
          end
      end)
    end

    @impl Vow.RegexOperator
    def unform(%@for{vows: vows}, val)
        when is_list(val) and length(val) >= 0 do
      vows
      |> Keyword.values()
      |> Enum.reverse()
      |> Enum.reduce({:ok, val}, fn
        _, {:error, reason} ->
          {:error, reason}

        vow, {:ok, unformed} ->
          Conformable.unform(vow, unformed)
      end)
    end

    def unform(vow, val) do
      {:error, %Vow.UnformError{vow: vow, val: val}}
    end

    @spec conform_impl(Vow.t(), [term], [Vow.Ref.t()], [term], term) ::
            {:ok, Conformable.conformed(), @protocol.rest} | {:error, [ConformError.Problem.t()]}
    defp conform_impl(vow, path, via, route, val) do
      if Vow.regex?(vow) do
        @protocol.conform(vow, path, via, route, val)
      else
        case Conformable.conform(vow, path, via, Utils.uninit_path(route), val) do
          {:ok, conformed} -> {:ok, [conformed], []}
          {:error, problems} -> {:error, problems}
        end
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow, opts) do
        @protocol.gen(Vow.also(vow.vows), opts)
      end
    end
  end
end
