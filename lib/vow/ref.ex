defmodule Vow.Ref do
  @moduledoc """
  TODO
  """

  import Vow.FunctionWrapper, only: [wrap: 1]

  defstruct [:mod, :fun]

  @type t :: %__MODULE__{
          mod: module | nil,
          fun: atom
        }

  @doc false
  @spec new(module | nil, atom) :: t
  def new(module, function) do
    %__MODULE__{
      mod: module,
      fun: function
    }
  end

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
  @spec sref(module | nil, atom) :: Macro.t
  defmacro sref(module \\ nil, function) do
    module = module || __CALLER__.module
    quote do
      Vow.Ref.new(
        unquote(module),
        unquote(function)
      )
    end
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    alias Vow.ConformError

    @impl Vow.RegexOperator
    def conform(ref, vow_path, via, value_path, value) do
      case @for.resolve(ref) do
        {:error, reasons} ->
          {:error,
           Enum.map(reasons, fn {p, r} ->
             ConformError.new_problem(p, vow_path, via ++ [ref], value_path, value, r)
           end)}

        {:ok, vow} ->
          if Vow.regex?(vow) do
            @protocol.conform(vow, vow_path, via ++ [ref], value_path, value)
          else
            case Vow.Conformable.conform(vow, vow_path, via, value_path, value) do
              {:ok, conformed} -> {:ok, conformed, []}
              {:error, problems} -> {:error, problems}
            end
          end
      end
    end

    @impl Vow.RegexOperator
    def unform(vow, value) do
      Vow.Conformable.unform(vow, value)
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(ref, vow_path, via, value_path, value) do
      case @for.resolve(ref) do
        {:ok, vow} ->
          @protocol.conform(vow, vow_path, via ++ [ref], value_path, value)

        {:error, reasons} ->
          {:error,
           Enum.map(reasons, fn r ->
             ConformError.new_problem(r, vow_path, via ++ [ref], value_path, value)
           end)}
      end
    end

    @impl Vow.Conformable
    def unform(vow, value) do
      case @for.resolve(vow) do
        {:ok, vow} ->
          @protocol.unform(vow, value)
        {:error, _} ->
          {:error, %Vow.UnformError{vow: vow, value: value}}
      end
    end
  end

  # coveralls-ignore-start
  defimpl Inspect do
    @moduledoc false

    def inspect(%@for{mod: nil, fun: fun}, _opts) do
      "#SRef<#{fun}>"
    end
    def inspect(%@for{mod: mod, fun: fun}, _opts) do
      "#SRef<#{mod}.#{fun}>"
    end
  end

  # coveralls-ignore-stop
end
