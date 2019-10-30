defmodule Vow.Also do
  @moduledoc false

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
          case @protocol.conform(s, vow_path, via, value_path, c) do
            {:ok, conformed} -> {:ok, conformed}
            {:error, problems} -> {:error, problems}
          end
      end)
    end
  end
end
