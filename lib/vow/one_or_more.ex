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

    import Acs.Improper, only: [proper_list?: 1]
    import Vow.Utils, only: [append: 2]
    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(%@for{vow: vow}, path, via, route, value)
        when is_list(value) and length(value) >= 0 do
      case conform_first(vow, path, via, route, value) do
        {:error, problems} ->
          {:error, problems}

        {:ok, ch, rest} ->
          case @protocol.conform(
                 Vow.zom(vow),
                 path,
                 via,
                 Utils.inc_path(route),
                 rest
               ) do
            {:ok, ct, rest} ->
              {:ok, append(ch, ct), rest}

            {:error, _problems} ->
              {:ok, ch, rest}
          end
      end
    end

    def conform(_vow, path, via, route, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           path,
           via,
           Utils.uninit_path(route),
           value
         )
       ]}
    end

    def conform(_vow, path, via, route, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           path,
           via,
           Utils.uninit_path(route),
           value
         )
       ]}
    end

    @impl Vow.RegexOperator
    def unform(vow, []) do
      {:error, %Vow.UnformError{vow: vow, value: []}}
    end

    def unform(vow, value) do
      @protocol.Vow.ZeroOrMore.unform(vow, value)
    end

    @spec conform_first(Vow.t(), [term], [Vow.Ref.t()], [term], [term]) ::
            {:ok, conformed :: [term], rest :: [term]} | {:error, [ConformError.Problem.t()]}
    defp conform_first(vow, path, via, route, []) do
      {:error,
       [
         ConformError.new_problem(
           vow,
           path,
           via,
           Utils.uninit_path(route),
           [],
           "Insufficient Data"
         )
       ]}
    end

    defp conform_first(vow, path, via, route, [h | t] = value) do
      if Vow.regex?(vow) do
        @protocol.conform(vow, path, via, route, value)
      else
        case Conformable.conform(vow, path, via, route, h) do
          {:ok, conformed} -> {:ok, [conformed], t}
          {:error, problems} -> {:error, problems}
        end
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false
      import Vow.Utils, only: [append: 2]

      @impl Vow.Generatable
      def gen(vow, opts) do
        case @protocol.gen(vow.vow, opts) do
          {:error, reason} ->
            {:error, reason}

          {:ok, data} ->
            if Vow.regex?(vow.vow) do
              {:ok,
               StreamData.map(
                 StreamData.list_of(data, min_length: 1),
                 fn l -> Enum.reduce(l, [], &append/2) end
               )}
            else
              {:ok, StreamData.list_of(data, min_length: 1)}
            end
        end
      end
    end
  end
end
