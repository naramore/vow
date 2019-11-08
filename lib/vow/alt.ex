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
    def conform(%@for{vows: vows}, path, via, route, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(vows, {:error, []}, fn
        _, {:ok, c, r} ->
          {:ok, c, r}

        {k, s}, {:error, pblms} ->
          if Vow.regex?(s) do
            case @protocol.conform(s, [k|path], via, route, value) do
              {:ok, conformed, rest} -> {:ok, [%{k => conformed}], rest}
              {:error, problems} -> {:error, pblms ++ problems}
            end
          else
            route = Utils.uninit_path(route)

            with [h | t] <- value,
                 {:ok, conformed} <- Conformable.conform(s, [k|path], via, route, h) do
              {:ok, [%{k => conformed}], t}
            else
              {:error, problems} ->
                {:error, pblms ++ problems}

              [] ->
                {:error,
                 [
                   ConformError.new_problem(
                     s,
                     path,
                     via,
                     route,
                     [],
                     "Insufficient Data"
                   )
                 ]}
            end
          end
      end)
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
      def gen(vow, opts) do
        @protocol.Vow.OneOf.gen(Vow.one_of(vow.vows), opts)
      end
    end
  end
end
