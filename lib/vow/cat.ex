defmodule Vow.Cat do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct [:vows]

  @type t :: %__MODULE__{
          vows: [{atom, Vow.t()}, ...]
        }

  @spec new([{atom, Vow.t()}, ...]) :: t | no_return
  def new(named_vows) do
    vow = %__MODULE__{vows: named_vows}

    if unique_keys?(named_vows) do
      vow
    else
      raise %Vow.DuplicateNameError{vow: vow}
    end
  end

  @spec unique_keys?([{atom, Vow.t()}]) :: boolean | no_return
  def unique_keys?(named_vows) do
    if Enum.all?(named_vows, &match?({name, _} when is_atom(name), &1)) do
      {keys, _} = Enum.unzip(named_vows)
      unique_keys = Enum.uniq(keys)
      length(keys) == length(unique_keys)
    else
      raise %Vow.UnnamedVowsError{vows: named_vows}
    end
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Acs.Improper, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOperator, Utils}

    @type result ::
            {:ok, RegexOperator.conformed(), RegexOperator.rest()}
            | {:error, [ConformError.Problem.t()]}

    @impl Vow.RegexOperator
    def conform(%@for{vows: vows} = vow, path, via, route, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(
        vows,
        {:ok, %{}, value},
        conform_reducer(vow, path, via, route)
      )
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
      Enum.reduce(vows, {:ok, []}, fn
        _, {:error, reason} ->
          {:error, reason}

        {k, v}, {:ok, acc} ->
          if Map.has_key?(value, k) do
            case Conformable.unform(v, Map.get(value, k)) do
              {:error, reason} -> {:error, reason}
              {:ok, unformed} -> {:ok, Utils.append(acc, unformed)}
            end
          else
            {:error, %Vow.UnformError{vow: vow, value: value}}
          end
      end)
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end

    @spec conform_reducer(Vow.t(), [term], [Vow.Ref.t()], [term]) ::
            ({atom, Vow.t()}, result -> result)
    defp conform_reducer(vow, path, via, route) do
      &conform_reducer(vow, path, via, route, &1, &2)
    end

    @spec conform_reducer(
            Vow.t(),
            [term],
            [Vow.Ref.t()],
            [term],
            {atom, Vow.t()},
            result
          ) :: result
    defp conform_reducer(_, _, _, _, _, {:error, pblms}) do
      {:error, pblms}
    end

    defp conform_reducer(vow, path, via, route, {k, s}, {:ok, acc, []}) do
      if Vow.regex?(s) do
        case @protocol.conform(s, [k|path], via, route, []) do
          {:ok, c, rest} -> {:ok, Map.put(acc, k, c), rest}
          {:error, problems} -> {:error, problems}
        end
      else
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
    end

    defp conform_reducer(_vow, path, via, route, {k, s}, {:ok, acc, [h | t] = r}) do
      if Vow.regex?(s) do
        case @protocol.conform(s, [k | path], via, route, r) do
          {:ok, c, rest} -> {:ok, Map.put(acc, k, c), rest}
          {:error, problems} -> {:error, problems}
        end
      else
        case Conformable.conform(s, [k | path], via, Utils.uninit_path(route), h) do
          {:ok, c} -> {:ok, Map.put(acc, k, c), t}
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
        Enum.reduce(vow.vows, {:ok, []}, fn
          _, {:error, reason} ->
            {:error, reason}

          {k, v}, {:ok, acc} ->
            case @protocol.gen(v, opts) do
              {:error, reason} -> {:error, reason}
              {:ok, data} -> {:ok, [StreamData.tuple({StreamData.constant(k), data}) | acc]}
            end
        end)
        |> case do
          {:error, reason} ->
            {:error, reason}

          {:ok, datas} ->
            {:ok,
             datas
             |> :lists.reverse()
             |> StreamData.fixed_list()
             |> StreamData.map(
               fn ele ->
                Enum.reduce(ele, [], fn {k, v}, acc ->
                  if Vow.regex?(Keyword.get(ele, k)) do
                    append(v, acc)
                  else
                    [v | acc]
                  end
                end)
                |> :lists.reverse()
               end
             )}
        end
      end
    end
  end
end
