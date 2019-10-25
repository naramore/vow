defmodule Vow.OneOf do
  @moduledoc false

  defstruct [:specs]

  @type t :: %__MODULE__{
          specs: [{atom, Vow.t()}, ...]
        }

  @spec new([Vow.t()]) :: t
  def new(named_specs) do
    spec = %__MODULE__{specs: named_specs}

    if Vow.Cat.unique_keys?(named_specs) do
      spec
    else
      raise %Vow.DuplicateNameError{spec: spec}
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    def conform(%@for{specs: [{k, spec}]}, spec_path, via, value_path, value) do
      case @protocol.conform(spec, spec_path ++ [k], via, value_path, value) do
        {:ok, conformed} -> {:ok, %{k => conformed}}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(%@for{specs: specs}, spec_path, via, value_path, value)
        when is_list(specs) and length(specs) > 0 do
      Enum.reduce(specs, {:error, []}, fn
        _, {:ok, c} ->
          {:ok, c}

        {k, s}, {:error, pblms} ->
          case @protocol.conform(s, spec_path ++ [k], via, value_path, value) do
            {:ok, conformed} -> {:ok, %{k => conformed}}
            {:error, problems} -> {:error, pblms ++ problems}
          end
      end)
    end
  end
end
