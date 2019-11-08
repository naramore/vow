defmodule Vow.Maybe do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :passthrough

  defstruct vow: nil

  @type t :: %__MODULE__{
          vow: Vow.t()
        }

  @spec new(Vow.t()) :: t
  def new(vow) do
    %__MODULE__{vow: vow}
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Acs.Improper, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(_vow, _path, _via, _route, []) do
      {:ok, [], []}
    end

    def conform(%@for{vow: vow}, path, via, route, [h | t] = value)
        when is_list(value) and length(value) >= 0 do
      if Vow.regex?(vow) do
        @protocol.conform(vow, path, via, route, value)
      else
        case Conformable.conform(vow, path, via, route, h) do
          {:ok, conformable} -> {:ok, [conformable], t}
          {:error, _problems} -> {:ok, [], value}
        end
      end
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
    def unform(_vow, []), do: {:ok, []}

    def unform(%@for{vow: vow}, [value]) do
      Conformable.unform(vow, value)
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow, opts) do
        case @protocol.gen(vow.vow, opts) do
          {:error, reason} ->
            {:error, reason}

          {:ok, data} ->
            if Vow.regex?(vow.vow) do
              {:ok,
               StreamData.map(
                 StreamData.list_of(data, length: 0..1),
                 fn
                   [x] when is_list(x) -> x
                   otherwise -> otherwise
                 end
               )}
            else
              {:ok, StreamData.list_of(data, length: 0..1)}
            end
        end
      end
    end
  end
end
