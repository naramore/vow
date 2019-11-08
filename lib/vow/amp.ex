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

    import Acs.Improper, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(%@for{vows: []}, _path, _via, _route, value)
        when is_list(value) and length(value) >= 0 do
      {:ok, value, []}
    end

    def conform(%@for{vows: vows}, path, via, route, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(vows, {:ok, value, []}, fn
        _, {:error, pblms} ->
          {:error, pblms}

        {k, v}, {:ok, c, rest} ->
          case conform_impl(v, [k|path], via, route, c) do
            {:ok, conformed, tail} -> {:ok, conformed, tail ++ rest}
            {:error, problems} -> {:error, problems}
          end
      end)
    end

    def conform(_vow, path, via, route, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           path,
           via,
           Utils.uninit_path(route),
           value
         )
       ]}
    end

    def conform(_vow, path, via, route, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           path,
           via,
           Utils.uninit_path(route),
           value
         )
       ]}
    end

    @impl Vow.RegexOperator
    def unform(%@for{vows: vows}, value)
        when is_list(value) and length(value) >= 0 do
      vows
      |> Keyword.values()
      |> Enum.reverse()
      |> Enum.reduce({:ok, value}, fn
        _, {:error, reason} ->
          {:error, reason}

        vow, {:ok, unformed} ->
          Conformable.unform(vow, unformed)
      end)
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end

    @spec conform_impl(Vow.t(), [term], [Vow.Ref.t()], [term], term) ::
            {:ok, Conformable.conformed(), @protocol.rest} | {:error, [ConformError.Problem.t()]}
    defp conform_impl(vow, path, via, route, value) do
      if Vow.regex?(vow) do
        @protocol.conform(vow, path, via, route, value)
      else
        case Conformable.conform(vow, path, via, Utils.uninit_path(route), value) do
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
