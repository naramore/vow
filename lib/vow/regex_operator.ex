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
  def conform(vow, path, via, route, value)

  @doc """
  """
  @spec unform(t, conformed) :: {:ok, value :: term} | {:error, Vow.UnformError.t()}
  def unform(vow, conformed_value)
end

alias Vow.{Alt, Amp, Cat, Maybe, OneOrMore, ZeroOrMore}

defimpl Vow.Conformable, for: [Alt, Amp, Cat, Maybe, OneOrMore, ZeroOrMore] do
  @moduledoc false

  import Acs.Improper, only: [proper_list?: 1]
  alias Vow.{ConformError, Utils, RegexOperator}

  @impl Vow.Conformable
  def conform(vow, path, via, route, value)
      when is_list(value) and length(value) >= 0 do
    case RegexOperator.conform(vow, path, via, Utils.init_path(route), value) do
      {:ok, conformed, []} ->
        {:ok, conformed}

      {:error, problems} ->
        {:error, problems}

      {:ok, _conformed, [_ | _]} ->
        {:error,
         [ConformError.new_problem(vow, path, via, route, value, "Insufficient Data")]}
    end
  end

  def conform(_vow, path, via, route, value) when is_list(value) do
    {:error, [ConformError.new_problem(&proper_list?/1, path, via, route, value)]}
  end

  def conform(_vow, path, via, route, value) do
    {:error, [ConformError.new_problem(&is_list/1, path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(vow, value) do
    RegexOperator.unform(vow, value)
  end
end
