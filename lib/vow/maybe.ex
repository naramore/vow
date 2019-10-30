defmodule Vow.Maybe do
  @moduledoc false

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

    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp}

    def conform(_vow, _vow_path, _via, _value_path, []) do
      {:ok, [], []}
    end

    def conform(%@for{vow: vow}, vow_path, via, value_path, [h | t] = value)
        when is_list(value) and length(value) >= 0 do
      if Vow.regex?(vow) do
        @protocol.conform(vow, vow_path, via, value_path, value)
      else
        case Conformable.conform(vow, vow_path, via, value_path, h) do
          {:ok, conformable} -> {:ok, [conformable], t}
          {:error, _problems} -> {:ok, [], value}
        end
      end
    end

    def conform(_vow, vow_path, via, value_path, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           vow_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           vow_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end
  end
end
