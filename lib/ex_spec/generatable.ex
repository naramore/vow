defprotocol ExSpec.Generatable do
  @moduledoc """
  """

  @fallback_to_any true
  if Code.ensure_loaded?(StreamData) do
    @type generator :: StreamData.t(term)
  else
    @type generator :: term
  end

  @doc """
  """
  @spec gen(t, [{[atom], (() -> generator)}]) :: {:ok, generator} | {:error, reason :: term}
  def gen(spec, overrides \\ [])
end

defimpl ExSpec.Generatable, for: Any do
  @moduledoc false

  def gen(_spec, _overrides) do
    {:error, :not_implemented}
  end
end
