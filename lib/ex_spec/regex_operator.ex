defprotocol ExSpec.RegexOperator do
  @moduledoc """
  """

  alias ExSpec.{Conformable, ConformError}

  @type conformed :: Conformable.conformed()
  @type rest :: maybe_improper_list(term, term) | term

  @doc """
  """
  @spec conform(t, [term], [ExSpec.Ref.t()], [term], term) ::
          {:ok, conformed, rest} | {:error, [ConformError.Problem.t()]}
  def conform(spec, spec_path, via, value_path, value)
end

alias ExSpec.{Alt, Amp, Cat, Maybe, OneOrMore, ZeroOrMore}

defimpl ExSpec.Conformable, for: [Alt, Amp, Cat, Maybe, OneOrMore, ZeroOrMore] do
  @moduledoc false

  import ExSpec.Conformable.ExSpec.List, only: [proper_list?: 1]
  alias ExSpec.{ConformError, RegexOp, RegexOperator}

  def conform(spec, spec_path, via, value_path, value)
      when is_list(value) and length(value) >= 0 do
    case RegexOperator.conform(spec, spec_path, via, RegexOp.init_path(value_path), value) do
      {:ok, conformed, []} ->
        {:ok, conformed}

      {:error, problems} ->
        {:error, problems}

      {:ok, _conformed, [_ | _]} ->
        {:error,
         [ConformError.new_problem(:insufficient_data, spec_path, via, value_path, value)]}
    end
  end

  def conform(_spec, spec_path, via, value_path, value) when is_list(value) do
    {:error, [ConformError.new_problem(&proper_list?/1, spec_path, via, value_path, value)]}
  end

  def conform(_spec, spec_path, via, value_path, value) do
    {:error, [ConformError.new_problem(&is_list/1, spec_path, via, value_path, value)]}
  end
end
