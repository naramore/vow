defmodule Vow.Func do
  @moduledoc """
  TODO
  """

  defstruct [:function, :form]

  @type t :: %__MODULE__{
          function: (term -> boolean),
          form: String.t()
        }

  @doc false
  @spec new((term -> boolean), String.t()) :: t
  def new(function, form) do
    %__MODULE__{
      function: function,
      form: form
    }
  end

  @doc """
  """
  @spec f((term -> boolean)) :: Macro.t()
  defmacro f(function) do
    func = build(function)

    quote do
      unquote(func)
    end
  end

  @doc false
  @spec build(Macro.t()) :: Macro.t()
  defp build(quoted) do
    form = Macro.to_string(quoted)

    quote do
      %Vow.Func{function: unquote(quoted), form: unquote(form)}
    end
  end

  defimpl Inspect do
    @moduledoc false

    def inspect(%@for{form: form}, _opts) do
      to_string(form)
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    def conform(%@for{function: fun} = func, spec_path, via, value_path, value) do
      case @protocol.Function.conform(fun, spec_path, via, value_path, value) do
        {:ok, conformed} ->
          {:ok, conformed}

        {:error, [%{predicate: ^fun} = problem]} ->
          {:error, [%{problem | predicate: func.form}]}

        {:error, problems} ->
          {:error, problems}
      end
    end
  end
end