defmodule Vow.Alt do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct [:vows]

  @type t :: %__MODULE__{
          vows: [{atom, Vow.t()}, ...]
        }

  @spec new([Vow.t()]) :: t
  def new(named_vows) do
    vow = %__MODULE__{vows: named_vows}

    if Vow.Cat.unique_keys?(named_vows) do
      vow
    else
      raise %Vow.DuplicateNameError{vow: vow}
    end
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Acs.Improper, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, Utils}

    @impl Vow.RegexOperator
    def conform(%@for{vows: vows}, vow_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(vows, {:error, []}, fn
        _, {:ok, c, r} ->
          {:ok, c, r}

        {k, s}, {:error, pblms} ->
          if Vow.regex?(s) do
            case @protocol.conform(s, vow_path ++ [k], via, value_path, value) do
              {:ok, conformed, rest} -> {:ok, [%{k => conformed}], rest}
              {:error, problems} -> {:error, pblms ++ problems}
            end
          else
            value_path = Utils.uninit_path(value_path)

            with [h | t] <- value,
                 {:ok, conformed} <- Conformable.conform(s, vow_path ++ [k], via, value_path, h) do
              {:ok, [%{k => conformed}], t}
            else
              {:error, problems} ->
                {:error, pblms ++ problems}

              [] ->
                {:error,
                 [
                   ConformError.new_problem(
                     s,
                     vow_path,
                     via,
                     value_path,
                     [],
                     "Insufficient Data"
                   )
                 ]}
            end
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
    def unform(%@for{vows: vows} = vow, value) when is_map(value) do
      with [key] <- Map.keys(value),
           true <- Keyword.has_key?(vows, key) do
        Conformable.unform(Keyword.get(vows, key), Map.get(value, key))
      else
        _ -> {:error, %Vow.UnformError{vow: vow, value: value}}
      end
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow) do
        @protocol.Vow.OneOf.gen(Vow.one_of(vow.vows))
      end
    end
  end
end
