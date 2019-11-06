defmodule Vow.Amp do
  @moduledoc false
  use Vow.Utils.AccessShortcut,
    type: :many_passthrough

  defstruct [:vows]

  @type t :: %__MODULE__{
          vows: [Vow.t()]
        }

  @spec new([Vow.t()]) :: t
  def new(vows) do
    %__MODULE__{vows: vows}
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Acs.Improper, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(%@for{vows: []}, _vow_path, _via, _value_path, value)
        when is_list(value) and length(value) >= 0 do
      {:ok, value, []}
    end

    def conform(%@for{vows: vows}, vow_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(vows, {:ok, value, []}, fn
        _, {:error, pblms} ->
          {:error, pblms}

        s, {:ok, c, rest} ->
          case conform_impl(s, vow_path, via, value_path, c) do
            {:ok, conformed, tail} -> {:ok, conformed, tail ++ rest}
            {:error, problems} -> {:error, problems}
          end
      end)
    end

    def conform(_vow, vow_path, via, value_path, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           vow_path,
           via,
           Utils.uninit_path(value_path),
           value
         )
       ]}
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           vow_path,
           via,
           Utils.uninit_path(value_path),
           value
         )
       ]}
    end

    @impl Vow.RegexOperator
    def unform(%@for{vows: vows}, value)
        when is_list(value) and length(value) >= 0 do
      vows
      |> Enum.reverse()
      |> Enum.reduce({:ok, value}, fn
        _, {:error, reason} ->
          {:error, reason}

        vow, {:ok, unformed} ->
          Conformable.unform(vow, unformed)
      end)
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end

    @spec conform_impl(Vow.t(), [term], [Vow.Ref.t()], [term], term) ::
            {:ok, Conformable.conformed(), @protocol.rest} | {:error, [ConformError.Problem.t()]}
    defp conform_impl(vow, vow_path, via, value_path, value) do
      if Vow.regex?(vow) do
        @protocol.conform(vow, vow_path, via, value_path, value)
      else
        case Conformable.conform(vow, vow_path, via, Utils.uninit_path(value_path), value) do
          {:ok, conformed} -> {:ok, [conformed], []}
          {:error, problems} -> {:error, problems}
        end
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow) do
        @protocol.Vow.Also.gen(Vow.also(vow.vows))
      end
    end
  end
end
