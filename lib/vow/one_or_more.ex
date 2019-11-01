defmodule Vow.OneOrMore do
  @moduledoc false

  defstruct [:vow]

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
    import Vow.RegexOperator.Vow.ZeroOrMore, only: [append: 2]
    alias Vow.{Conformable, ConformError, RegexOp}

    @impl Vow.RegexOperator
    def conform(%@for{vow: vow}, vow_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      case conform_first(vow, vow_path, via, value_path, value) do
        {:error, problems} ->
          {:error, problems}

        {:ok, ch, rest} ->
          case @protocol.conform(
                 Vow.zom(vow),
                 vow_path,
                 via,
                 RegexOp.inc_path(value_path),
                 rest
               ) do
            {:ok, ct, rest} ->
              {:ok, append(ch, ct), rest}

            {:error, _problems} ->
              {:ok, ch, rest}
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

    @impl Vow.RegexOperator
    def unform(vow, []) do
      {:error, %Vow.UnformError{vow: vow, value: []}}
    end
    def unform(vow, value) do
      @protocol.Vow.ZeroOrMore.unform(vow, value)
    end

    @spec conform_first(Vow.t(), [term], [Vow.Ref.t()], [term], [term]) ::
            {:ok, conformed :: [term], rest :: [term]} | {:error, [ConformError.Problem.t()]}
    defp conform_first(vow, vow_path, via, value_path, []) do
      {:error,
       [
         ConformError.new_problem(
           vow,
           vow_path,
           via,
           RegexOp.uninit_path(value_path),
           [],
           "Insufficient Data"
         )
       ]}
    end

    defp conform_first(vow, vow_path, via, value_path, [h | t] = value) do
      if Vow.regex?(vow) do
        @protocol.conform(vow, vow_path, via, value_path, value)
      else
        case Conformable.conform(vow, vow_path, via, value_path, h) do
          {:ok, conformed} -> {:ok, [conformed], t}
          {:error, problems} -> {:error, problems}
        end
      end
    end
  end
end
