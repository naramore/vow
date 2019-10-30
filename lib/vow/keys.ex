defmodule Vow.Keys do
  @moduledoc false

  defstruct []
  @type t :: %__MODULE__{}

  @spec new(keyword) :: t
  def new(_opts) do
    %__MODULE__{}
  end

  defimpl Vow.Conformable do
    @moduledoc false

    def conform(_vow, _vow_path, _via, _value_path, _value) do
      # 1. process key 'grammar'
      # 2. validate the value's keys are 'accepted'
      # 3. conform the value of each key against the referenced vow
      # 4. Enum.into(conformed, vow.into)
      {:error, []}
    end
  end
end
