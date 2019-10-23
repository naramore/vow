defmodule ExSpec.Nilable do
  @moduledoc false

  defstruct [:spec]

  @type t :: %__MODULE__{
          spec: ExSpec.t()
        }

  @spec new(ExSpec.t()) :: t
  def new(spec) do
    %__MODULE__{spec: spec}
  end

  defimpl ExSpec.Conformable do
    @moduledoc false

    def conform(_spec, _spec_path, _via, _value_path, nil) do
      {:ok, nil}
    end

    def conform(spec, spec_path, via, value_path, value) do
      @protocol.conform(spec, spec_path, via, value_path, value)
    end
  end
end
