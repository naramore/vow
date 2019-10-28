defmodule Vow.Alt do
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

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp}

    def conform(%@for{specs: specs}, spec_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(specs, {:error, []}, fn
        _, {:ok, c, r} ->
          {:ok, c, r}

        {k, s}, {:error, pblms} ->
          if Vow.regex?(s) do
            case @protocol.conform(s, spec_path ++ [k], via, value_path, value) do
              {:ok, conformed, rest} -> {:ok, %{k => conformed}, rest}
              {:error, problems} -> {:error, pblms ++ problems}
            end
          else
            value_path = RegexOp.uninit_path(value_path)

            with [h | t] <- value,
                 {:ok, conformed} <- Conformable.conform(s, spec_path ++ [k], via, value_path, h) do
              {:ok, [%{k => conformed}], t}
            else
              {:error, problems} ->
                {:error, pblms ++ problems}

              [] ->
                {:error,
                 [
                   ConformError.new_problem(
                     s,
                     spec_path,
                     via,
                     value_path,
                     [],
                     "Insufficient Data"
                   )
                 ]}
            end
          end
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
