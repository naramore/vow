defmodule Vow.Pat do
  @moduledoc """
  This module provides a vow for wrapping a pattern and the `Vow.Pat.pat/1`
  macro for conveniently wrapping the pattern and packaging it in `Vow.Pat.t`.

  # Note

  Installation of the `Expat` package is recommended if using this module as
  `Expat` provides excellent utilities for defining and reusing patterns.

    ```
    def deps do
      [{:expat, "~> 1.0"}]
    end
    ```
  """

  use Vow.Utils.AccessShortcut,
    type: :passthrough,
    passthrough_key: :pat

  import Kernel, except: [match?: 2]

  defstruct [:pat]

  @type t :: %__MODULE__{
          pat: Macro.t()
        }

  @doc false
  @spec new(Macro.t()) :: t | no_return
  def new(pattern) do
    %__MODULE__{pat: pattern}
  end

  @doc """
  Wraps a pattern and stores it in `Vow.Pat.t` for later matching.

  ## Examples

    ```
    iex> import Vow.Pat
    ...> p = pat({:ok, _})
    ...> Vow.conform(p, {:ok, :foo})
    {:ok, {:ok, :foo}}
    ```
  """
  @spec pat(Macro.t()) :: Macro.t()
  defmacro pat(pat) do
    quote do
      Vow.Pat.new(unquote(Macro.escape(Macro.expand(pat, __ENV__))))
    end
  end

  @doc """
  A convenience function that checks if the right side (an expresssion),
  matches the left side (a `Vow.Pat`).
  """
  @spec match?(t, expr :: term) :: boolean | no_return
  def match?(%__MODULE__{pat: pat}, expr) do
    {result, _bindings} =
      Code.eval_quoted(
        quote do
          Kernel.match?(unquote(pat), unquote(expr))
        end
      )

    result
  end

  defimpl Vow.Conformable do
    @moduledoc false
    import Vow.FunctionWrapper, only: [wrap: 2]
    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(vow, path, via, route, val) do
      if @for.match?(vow, val) do
        {:ok, val}
      else
        pred = wrap(&@for.match?(vow, &1), vow: vow)
        {:error, [ConformError.new_problem(pred, path, via, route, val)]}
      end
    rescue
      error ->
        msg = Exception.message(error)
        {:error, [ConformError.new_problem(vow, path, via, route, val, msg)]}
    end

    @impl Vow.Conformable
    def unform(_vow, val) do
      {:ok, val}
    end

    @impl Vow.Conformable
    def regex?(_vow), do: false
  end

  defimpl Inspect do
    @moduledoc false

    @impl Inspect
    def inspect(%@for{pat: pat}, _opts) do
      Macro.to_string(pat)
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      alias Vow.Utils
      import StreamData

      @impl Vow.Generatable
      def gen(vow, opts) do
        ignore_warn? = Keyword.get(opts, :ignore_warn?, false)
        _ = Utils.no_override_warn(vow, ignore_warn?)

        {:ok, filter(term(), &@for.match?(vow, &1))}
      end
    end
  end
end
