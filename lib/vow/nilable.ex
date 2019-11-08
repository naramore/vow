defmodule Vow.Nilable do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :passthrough

  defstruct [:vow]

  @type t :: %__MODULE__{
          vow: Vow.t()
        }

  @spec new(Vow.t()) :: t
  def new(vow) do
    %__MODULE__{vow: vow}
  end

  defimpl Vow.Conformable do
    @moduledoc false

    @impl Vow.Conformable
    def conform(_vow, _vow_path, _via, _value_path, nil) do
      {:ok, nil}
    end

    def conform(%@for{vow: vow}, vow_path, via, value_path, value) do
      @protocol.conform(vow, vow_path, via, value_path, value)
    end

    @impl Vow.Conformable
    def unform(_vow, nil), do: {:ok, nil}
    def unform(%@for{vow: vow}, value), do: @protocol.unform(vow, value)
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
            {:ok,
             StreamData.one_of([
               StreamData.constant(nil),
               data
             ])}
        end
      end
    end
  end
end
