defmodule Vow.OneOf do
  @moduledoc false

  defstruct [:vows]

  @type t :: %__MODULE__{
          vows: [{atom, Vow.t()}, ...]
        }

  @spec new([Vow.t()]) :: t
  def new(named_vows) do
    vow = %__MODULE__{vows: named_vows}

    if Vow.Cat.unique_keys?(named_vows) do
      vow
    else
      raise %Vow.DuplicateNameError{vow: vow}
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    def conform(%@for{vows: [{k, vow}]}, vow_path, via, value_path, value) do
      case @protocol.conform(vow, vow_path ++ [k], via, value_path, value) do
        {:ok, conformed} -> {:ok, %{k => conformed}}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(%@for{vows: vows}, vow_path, via, value_path, value)
        when is_list(vows) and length(vows) > 0 do
      Enum.reduce(vows, {:error, []}, fn
        _, {:ok, c} ->
          {:ok, c}

        {k, s}, {:error, pblms} ->
          case @protocol.conform(s, vow_path ++ [k], via, value_path, value) do
            {:ok, conformed} -> {:ok, %{k => conformed}}
            {:error, problems} -> {:error, pblms ++ problems}
          end
      end)
    end
  end
end
