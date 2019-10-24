defmodule Vow.Amp do
  @moduledoc false

  defstruct [:specs]

  @type t :: %__MODULE__{
          specs: [{atom, Vow.t()}]
        }

  @spec new([Vow.t()]) :: t
  def new(specs) do
    %__MODULE__{specs: specs}
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp}

    def conform(%@for{specs: []}, _spec_path, _via, _value_path, value) do
      {:ok, value, []}
    end

    def conform(%@for{specs: [spec]}, spec_path, via, value_path, value) do
      if Vow.regex?(spec) do
        @protocol.conform(spec, spec_path, via, value_path, value)
      else
        case Conformable.conform(spec, spec_path, via, RegexOp.uninit_path(value_path), value) do
          {:ok, conformed} -> {:ok, conformed, []}
          {:error, problems} -> {:error, problems}
        end
      end
    end

    def conform(%@for{specs: specs}, spec_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(specs, {:ok, value, []}, fn
        _, {:error, pblms} ->
          {:error, pblms}

        s, {:ok, c, _} ->
          @protocol.conform(@for.new([s]), spec_path, via, value_path, c)
      end)
    end

    def conform(_spec, spec_path, via, value_path, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           spec_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           spec_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end
  end
end
