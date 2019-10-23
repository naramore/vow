defmodule ExSpec.OneOf do
  @moduledoc false

  defstruct [:specs]

  @type t :: %__MODULE__{
          specs: [{atom, ExSpec.t()}, ...]
        }

  @spec new([ExSpec.t()]) :: t
  def new(named_specs) do
    spec = %__MODULE__{specs: named_specs}

    if ExSpec.Cat.unique_keys?(named_specs) do
      spec
    else
      raise %ExSpec.DuplicateNameError{spec: spec}
    end
  end

  defimpl ExSpec.Conformable do
    @moduledoc false

    import ExSpec.Conformable.ExSpec.List, only: [proper_list?: 1]
    alias ExSpec.ConformError

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

    def conform(_spec, spec_path, via, value_path, value) when is_list(value) do
      {:error, [ConformError.new_problem(&proper_list?/1, spec_path, via, value_path, value)]}
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_list/1, spec_path, via, value_path, value)]}
    end
  end
end
