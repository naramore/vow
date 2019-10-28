defmodule Vow.Ref do
  @moduledoc """
  TODO
  """

  import Vow.FunctionWrapper, only: [wrap: 1]

  defstruct [:mod, :fun]

  @type t :: %__MODULE__{
          mod: module,
          fun: atom
        }

  @doc false
  @spec resolve(t) :: {:ok, Vow.t()} | {:error, [{Vow.t(), String.t() | nil}]}
  def resolve(%__MODULE__{mod: mod, fun: fun})
      when is_atom(mod) and is_atom(fun) do
    if function_exported?(mod, fun, 0) do
      {:ok, apply(mod, fun, [])}
    else
      {:error, [{wrap(&function_exported?(&1.mod, &1.fun, 0)), nil}]}
    end
  rescue
    reason -> {:error, [{nil, reason}]}
  catch
    :exit, reason -> {:error, [{nil, "Vow reference exited: #{inspect(reason)}"}]}
    caught -> {:error, [{nil, "Vow reference threw: #{inspect(caught)}"}]}
  end

  def resolve(_ref) do
    {:error, [{wrap(&(is_atom(&1.mod) and is_atom(&1.fun))), nil}]}
  end

  @doc """
  """
  @spec sref(module, atom) :: t
  def sref(module, function) do
    %Vow.Ref{
      mod: module,
      fun: function
    }
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    alias Vow.ConformError

    def conform(ref, spec_path, via, value_path, value) do
      case @for.resolve(ref) do
        {:error, reasons} ->
          {:error,
           Enum.map(reasons, fn {p, r} ->
             ConformError.new_problem(p, spec_path, via ++ [ref], value_path, value, r)
           end)}

        {:ok, spec} ->
          if Vow.regex?(spec) do
            @protocol.conform(spec, spec_path, via ++ [ref], value_path, value)
          else
            case Vow.Conformable.conform(spec, spec_path, via, value_path, value) do
              {:ok, conformed} -> {:ok, conformed, []}
              {:error, problems} -> {:error, problems}
            end
          end
      end
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    alias Vow.ConformError

    def conform(ref, spec_path, via, value_path, value) do
      case @for.resolve(ref) do
        {:ok, spec} ->
          @protocol.conform(spec, spec_path, via ++ [ref], value_path, value)

        {:error, reasons} ->
          {:error,
           Enum.map(reasons, fn r ->
             ConformError.new_problem(r, spec_path, via ++ [ref], value_path, value)
           end)}
      end
    end
  end

  # coveralls-ignore-start
  defimpl Inspect do
    @moduledoc false

    def inspect(%@for{mod: mod, fun: fun}, _opts) do
      "#SRef<#{mod}.#{fun}>"
    end
  end

  # coveralls-ignore-stop
end
