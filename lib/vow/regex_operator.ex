defprotocol Vow.RegexOperator do
  @moduledoc """
  TODO
  """

  alias Vow.{Conformable, ConformError}

  @type conformed :: Conformable.conformed()
  @type rest :: maybe_improper_list(term, term) | term

  @doc """
  """
  @spec conform(t, [term], [Vow.Ref.t()], [term], term) ::
          {:ok, conformed, rest} | {:error, [ConformError.Problem.t()]}
  def conform(vow, vow_path, via, value_path, value)
end

alias Vow.{Alt, Amp, Cat, Maybe, OneOrMore, ZeroOrMore}

defimpl Vow.Conformable, for: [Alt, Amp, Cat, Maybe, OneOrMore, ZeroOrMore] do
  @moduledoc false

  import Vow.Conformable.Vow.List, only: [proper_list?: 1]
  alias Vow.{ConformError, RegexOp, RegexOperator}

  def conform(vow, vow_path, via, value_path, value)
      when is_list(value) and length(value) >= 0 do
    case RegexOperator.conform(vow, vow_path, via, RegexOp.init_path(value_path), value) do
      {:ok, conformed, []} ->
        {:ok, conformed}

      {:error, problems} ->
        {:error, problems}

      {:ok, _conformed, [_ | _]} ->
        {:error, [ConformError.new_problem(:insufficient_data, vow_path, via, value_path, value)]}
    end
  end

  def conform(_vow, vow_path, via, value_path, value) when is_list(value) do
    {:error, [ConformError.new_problem(&proper_list?/1, vow_path, via, value_path, value)]}
  end

  def conform(vow, vow_path, via, value_path, value) do
    if Enumerable.impl_for(value) do
      conform(vow, vow_path, via, value_path, Enum.to_list(value))
    else
      {:error, [ConformError.new_problem(&is_list/1, vow_path, via, value_path, value)]}
    end
  end
end
