defmodule Vow.FunctionWrapper do
  @moduledoc """
  This vow wraps an annoymous function for the purpose of improved error
  messages and readability of vows.

  The `Function` type impelements the `Inspect` protocol in Elixir, but
  annoymous functions are printed as something similar to the following:

    ```
    # regex to match something like: #Function<7.91303403/1 in :erl_eval.expr/5>
    iex> regex = ~r|^#Function<\\d+\\.\\d+?/1 in|
    ...> f = fn x -> x end
    ...> Regex.match?(regex, inspect(f))
    true
    ```

  Whereas a named function looks more reasonable:

    ```
    iex> inspect(&Kernel.apply/2)
    "&:erlang.apply/2"
    ```

  The `Vow.FunctionWrapper.wrap/2` macro can be used to alleviate this.

    ```
    iex> import Vow.FunctionWrapper, only: :macros
    ...> inspect(wrap(fn x -> x end))
    "fn x -> x end"
    ```

  It can also be used to optionally control the bindings within the annoymous
  function for printing purposes.

    ```
    iex> import Vow.FunctionWrapper, only: :macros
    ...> y = 42
    ...> inspect(wrap(fn x -> x + y end))
    "fn x -> x + y end"

    iex> import Vow.FunctionWrapper, only: :macros
    ...> y = 42
    ...> inspect(wrap(fn x -> x + y end, y: y))
    "fn x -> x + 42 end"
    ```
  """

  defstruct function: nil,
            form: nil,
            bindings: []

  @type t :: %__MODULE__{
          function: (term -> boolean),
          form: Macro.t(),
          bindings: keyword()
        }

  @doc false
  @spec new((term -> boolean), Macro.t(), keyword()) :: t
  def new(function, form, bindings \\ []) do
    %__MODULE__{
      function: function,
      form: form,
      bindings: bindings
    }
  end

  @doc """
  Creates a new `Vow.FunctionWrapper.t` using the AST of `quoted` and
  its resolved function.

  Optionally, specify the bindings within the quoted form to be used by
  the `Inspect` protocol.
  """
  @spec wrap(Macro.t(), keyword()) :: Macro.t()
  defmacro wrap(quoted, bindings \\ []) do
    quote do
      Vow.FunctionWrapper.new(
        unquote(quoted),
        unquote(Macro.escape(quoted)),
        unquote(bindings)
      )
    end
  end

  # coveralls-ignore-start
  defimpl Inspect do
    @moduledoc false

    @impl Inspect
    def inspect(%@for{form: form, bindings: bindings}, opts) do
      Macro.to_string(form, fn
        {var, _, mod}, string when is_atom(var) and is_atom(mod) ->
          if Keyword.has_key?(bindings, var) do
            Kernel.inspect(
              Keyword.get(bindings, var),
              opts_to_keyword(opts)
            )
          else
            string
          end

        _ast, string ->
          string
      end)
    end

    @spec opts_to_keyword(Inspect.Opts.t()) :: keyword
    defp opts_to_keyword(opts) do
      opts
      |> Map.from_struct()
      |> Enum.into([])
    end
  end

  # coveralls-ignore-stop

  defimpl Vow.Conformable do
    @moduledoc false

    @impl Vow.Conformable
    def conform(%@for{function: fun} = func, path, via, route, val) do
      case @protocol.Function.conform(fun, path, via, route, val) do
        {:ok, conformed} ->
          {:ok, conformed}

        {:error, [%{pred: ^fun} = problem]} ->
          {:error, [%{problem | pred: func.form}]}

        {:error, problems} ->
          {:error, problems}
      end
    end

    @impl Vow.Conformable
    def unform(_vow, val) do
      {:ok, val}
    end

    @impl Vow.Conformable
    def regex?(_vow), do: false
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(%@for{function: fun}, opts) do
        @protocol.Function.gen(fun, opts)
      end
    end
  end
end
