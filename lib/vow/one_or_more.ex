defmodule Vow.OneOrMore do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :passthrough

  defstruct [:vow]

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
    alias Vow.Utils

    @impl Vow.RegexOperator
    def conform(%@for{vow: vow}, path, via, route, val) do
      case @protocol.conform(vow, path, via, route, val) do
        {:error, problems} ->
          {:error, problems}

        {:ok, ch, rest} ->
          conform_rest(vow, path, via, route, rest, ch)
      end
    end

    @impl Vow.RegexOperator
    def unform(vow, []) do
      {:error, %Vow.UnformError{vow: vow, val: []}}
    end

    def unform(vow, val) do
      @protocol.Vow.ZeroOrMore.unform(vow, val)
    end

    @spec conform_rest(Vow.t(), [term], [Vow.Ref.t()], [term], [term], term) ::
            {:ok, @protocol.conformed, @protocol.rest}
    defp conform_rest(vow, path, via, route, rest, conformed_head) do
      zom = Vow.zom(vow)
      route = Utils.inc_path(route)

      case @protocol.conform(zom, path, via, route, rest) do
        {:ok, ct, rest} ->
          {:ok, append(conformed_head, ct), rest}

        {:error, _problems} ->
          {:ok, conformed_head, rest}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      import Vow.Utils, only: [append: 2]

      @impl Vow.Generatable
      def gen(vow, opts) do
        gen_impl(vow, opts, min_length: 1)
      end

      @spec gen_impl(Vow.t(), keyword, keyword) :: @protocol.result
      def gen_impl(vow, opts, list_opts) do
        case @protocol.gen(vow.vow, opts) do
          {:error, reason} ->
            {:error, reason}

          {:ok, data} ->
            if Vow.regex?(vow.vow) do
              {:ok,
               StreamData.map(
                 StreamData.list_of(data, list_opts),
                 fn l -> Enum.reduce(l, [], &append/2) end
               )}
            else
              {:ok, StreamData.list_of(data, list_opts)}
            end
        end
      end
    end
  end
end
