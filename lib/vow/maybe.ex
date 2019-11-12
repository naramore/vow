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

    alias Vow.Conformable

    @impl Vow.RegexOperator
    def conform(_vow, _path, _via, _route, []) do
      {:ok, [], []}
    end

    def conform(%@for{vow: vow}, path, via, route, val) do
      case @protocol.conform(vow, path, via, route, val) do
        {:error, _problems} -> {:ok, [], val}
        {:ok, conformed, rest} -> {:ok, [conformed], rest}
      end
    end

    @impl Vow.RegexOperator
    def unform(_vow, []) do
      {:ok, []}
    end

    def unform(%@for{vow: vow}, [val]) do
      Conformable.unform(vow, val)
    end

    def unform(vow, val) do
      {:error, %Vow.UnformError{vow: vow, val: val}}
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
