defmodule Vow.OneOrMore do
  @moduledoc false

  defstruct [:spec]

  @type t :: %__MODULE__{
          spec: Vow.t()
        }

  @spec new(Vow.t()) :: t
  def new(spec) do
    %__MODULE__{spec: spec}
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    use Vow.Func
    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp}

    def conform(%@for{spec: spec}, spec_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      case conform_first(spec, spec_path, via, value_path, value) do
        {:error, problems} ->
          {:error, problems}

        {:ok, ch, rest} ->
          case @protocol.conform(
                 Vow.zom(spec),
                 spec_path,
                 via,
                 RegexOp.inc_path(value_path),
                 rest
               ) do
            {:ok, ct, rest} ->
              {:ok, ch ++ ct, rest}

            {:error, problems} ->
              {:error, adjust_problems(problems, length(value_path) - 1)}
          end
      end
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

    @spec conform_first(Vow.t(), [term], [Vow.Ref.t()], [term], [term]) ::
            {:ok, conformed :: [term], rest :: [term]} | {:error, [ConformError.Problem.t()]}
    defp conform_first(_spec, spec_path, via, value_path, []) do
      {:error, [ConformError.new_problem(f(&(length(&1) > 0)), spec_path, via, value_path, [])]}
    end

    defp conform_first(spec, spec_path, via, value_path, [h | t] = value) do
      if Vow.regex?(spec) do
        @protocol.conform(spec, spec_path, via, value_path, value)
      else
        case Conformable.conform(spec, spec_path, via, value_path, h) do
          {:ok, conformed} -> {:ok, [conformed], t}
          {:error, problems} -> {:error, problems}
        end
      end
    end

    @spec adjust_problems([ConformError.Problem.t()], non_neg_integer) :: [
            ConformError.Problem.t()
          ]
    defp adjust_problems(problems, index) do
      update_in(
        problems,
        [Access.all(), :value_path, Access.at(index)],
        fn i -> i + 1 end
      )
    end
  end
end
