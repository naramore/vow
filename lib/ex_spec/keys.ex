defmodule ExSpec.Keys do
  @moduledoc false

  defstruct []
  @type t :: %__MODULE__{}

  @spec new(keyword) :: t
  def new(_opts) do
    %__MODULE__{}
  end

  defimpl ExSpec.Conformable do
    @moduledoc false

    def conform(_spec, _spec_path, _via, _value_path, _value) do
      # 1. process key 'grammar'
      # 2. validate the value's keys are 'accepted'
      # 3. conform the value of each key against the referenced spec
      # 4. Enum.into(conformed, spec.into)
      {:error, []}
    end
  end
end
