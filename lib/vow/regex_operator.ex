defprotocol Vow.RegexOperator do
  @moduledoc """
  TODO
  """

  alias Vow.{Conformable, ConformError}

  @fallback_to_any true

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

defimpl Vow.RegexOperator, for: Any do
  @moduledoc false
  alias Vow.{Conformable, ConformError.Problem}

  @impl Vow.RegexOperator
  def conform(vow, path, via, [_ | route], []) do
    {:error, [Problem.new(vow, path, via, route, [], "Insufficient Data")]}
  end

  def conform(vow, path, via, route, [h | t]) do
    case Conformable.conform(vow, path, via, route, h) do
      {:error, problems} -> {:error, problems}
      {:ok, conformed} -> {:ok, conformed, t}
    end
  end

  @impl Vow.RegexOperator
  def unform(vow, value) do
    Conformable.unform(vow, value)
  end
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
        {:error, [ConformError.new_problem(vow, path, via, route, value, "Insufficient Data")]}
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

  @impl Vow.Conformable
  def regex?(_vow), do: true
end
