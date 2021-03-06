defmodule Vow.ZeroOrMore do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :passthrough

  defstruct vow: nil

  @type t :: %__MODULE__{
          vow: Vow.t()
        }

  @spec new(Vow.t()) :: t
  def new(vow) do
    %__MODULE__{vow: vow}
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Vow.Utils, only: [append: 2]
    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(_vow, _path, _via, _route, []) do
      {:ok, [], []}
    end

    def conform(%@for{vow: vow}, path, via, route, val) do
      conform_impl(vow, path, via, route, val)
    end

    @impl Vow.RegexOperator
    def unform(%@for{vow: vow}, val)
        when is_list(val) and length(val) >= 0 do
      val
      |> Enum.reduce({:ok, []}, fn
        _, {:error, reason} ->
          {:error, reason}

        item, {:ok, acc} ->
          case Conformable.unform(vow, item) do
            {:error, reason} -> {:error, reason}
            {:ok, unformed} -> {:ok, [unformed | acc]}
          end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        {:ok, unformed} -> {:ok, :lists.reverse(unformed)}
      end
    end

    def unform(vow, val) do
      {:error, %Vow.UnformError{vow: vow, val: val}}
    end

    @spec conform_impl(Vow.t(), [term], [Vow.Ref.t()], [term], [term], [term]) ::
            {:ok, @protocol.conformed, @protocol.rest} | {:error, [ConformError.Problem.t()]}
    defp conform_impl(vow, path, via, route, rest, acc \\ [])

    defp conform_impl(vow, path, via, route, rest, acc) do
      case @protocol.conform(vow, path, via, route, rest) do
        {:error, _problems} ->
          {:ok, acc, rest}

        {:ok, conformed, rest} ->
          route = Utils.inc_path(route)
          conform_impl(vow, path, via, route, rest, append(acc, conformed))
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      import Vow.Generatable.Vow.OneOrMore, only: [gen_impl: 3]

      @impl Vow.Generatable
      def gen(vow, opts) do
        gen_impl(vow, opts, [])
      end
    end
  end
end
