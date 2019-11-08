defmodule Vow.Ref do
  @moduledoc """
  TODO
  """

  @behaviour Access

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ResolveError

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

  @impl Access
  def fetch(%__MODULE__{} = vow, key) do
    case resolve(vow) do
      {:ok, vow} -> Access.fetch(vow, key)
      {:error, _} -> :error
    end
  end

  @impl Access
  def get_and_update(%__MODULE__{} = vow, key, fun) do
    case resolve(vow) do
      {:ok, vow} -> Access.get_and_update(vow, key, fun)
      {:error, _} -> {nil, vow}
    end
  end

  @impl Access
  def pop(%__MODULE__{} = vow, key) do
    case resolve(vow) do
      {:ok, vow} -> Access.pop(vow, key)
      {:error, _} -> {nil, vow}
    end
  end

  @doc false
  @spec resolve(t) :: {:ok, Vow.t()} | {:error, ResolveError.t()}
  def resolve(%__MODULE__{mod: mod, fun: fun} = ref)
      when is_atom(mod) and is_atom(fun) do
    if function_exported?(mod, fun, 0) do
      {:ok, apply(mod, fun, [])}
    else
      {:error, ResolveError.new(ref, wrap(&function_exported?(&1.mod, &1.fun, 0)))}
    end
  rescue
    reason -> {:error, ResolveError.new(ref, nil, "#{inspect(reason)}")}
  catch
    :exit, reason ->
      {:error, ResolveError.new(ref, nil, "Vow reference exited: #{inspect(reason)}")}

    caught ->
      {:error, ResolveError.new(ref, nil, "Vow reference threw: #{inspect(caught)}")}
  end

  def resolve(ref) do
    {:error, ResolveError.new(ref, wrap(&(is_atom(&1.mod) and is_atom(&1.fun))))}
  end

  @doc """
  """
  @spec sref(module | nil, atom) :: Macro.t()
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
    alias Vow.ConformError.Problem

    @impl Vow.RegexOperator
    def conform(ref, vow_path, via, value_path, value) do
      case @for.resolve(ref) do
        {:error, error} ->
          {:error, [Problem.from_resolve_error(error, vow_path, via, value_path, value)]}

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
      Vow.Conformable.Vow.Ref.unform(vow, value)
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false
    alias Vow.ConformError.Problem

    @impl Vow.Conformable
    def conform(ref, vow_path, via, value_path, value) do
      case @for.resolve(ref) do
        {:ok, vow} ->
          @protocol.conform(vow, vow_path, via ++ [ref], value_path, value)

        {:error, error} ->
          {:error, [Problem.from_resolve_error(error, vow_path, via, value_path, value)]}
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

  defimpl Inspect do
    @moduledoc false

    def inspect(%@for{mod: nil, fun: fun}, _opts) do
      "#SRef<#{fun}>"
    end

    def inspect(%@for{mod: mod, fun: fun}, _opts) do
      "#SRef<#{mod}.#{fun}>"
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      import StreamDataUtils, only: [lazy: 1]
      alias Vow.Utils

      @impl Vow.Generatable
      def gen(vow, opts) do
        ignore_warn? = Keyword.get(opts, :ignore_warn?, false)
        _ = Utils.no_override_warn(vow, ignore_warn?)
        {:ok, lazy(delayed_gen(vow, opts))}
      end

      @spec delayed_gen(Vow.t(), keyword) ::
              {:ok, Vow.Generatable.generator()} | {:error, reason :: term}
      defp delayed_gen(vow, opts) do
        case @for.resolve(vow) do
          {:ok, vow} ->
            @protocol.gen(vow, opts)

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end
end
