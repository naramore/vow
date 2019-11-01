defmodule Vow.DuplicateNameError do
  @moduledoc false

  defexception [:vow]

  @type t :: %__MODULE__{
          vow: Vow.t()
        }

  @impl Exception
  def message(%__MODULE__{vow: vow}) do
    "Duplicate sub-vow names are not allowed in #{vow.__struct__}"
  end
end

defmodule Vow.UnnamedVowsError do
  @moduledoc false

  defexception [:vows]

  @type t :: %__MODULE__{
    vows: [Vow.t]
  }

  @impl Exception
  def message(%__MODULE__{}) do
    "Expected a list of named vows (i.e. [{atom, Vow.t}])."
  end
end

defmodule Vow.Cat do
  @moduledoc false

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

    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp, RegexOperator}

    @type result ::
            {:ok, RegexOperator.conformed(), RegexOperator.rest()}
            | {:error, [ConformError.Problem.t()]}

    def conform(%@for{vows: vows} = vow, vow_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(
        vows,
        {:ok, %{}, value},
        conform_reducer(vow, vow_path, via, value_path)
      )
    end

    def conform(_vow, vow_path, via, value_path, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           vow_path,
           via,
           RegexOp.uninit_path(value_path),
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
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    @spec conform_reducer(Vow.t(), [term], [Vow.Ref.t()], [term]) ::
            ({atom, Vow.t()}, result -> result)
    defp conform_reducer(vow, vow_path, via, value_path) do
      &conform_reducer(vow, vow_path, via, value_path, &1, &2)
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

    defp conform_reducer(vow, vow_path, via, value_path, {k, s}, {:ok, acc, []}) do
      if Vow.regex?(s) do
        case @protocol.conform(s, vow_path ++ [k], via, value_path, []) do
          {:ok, c, rest} -> {:ok, Map.put(acc, k, c), rest}
          {:error, problems} -> {:error, problems}
        end
      else
        {:error,
         [
           ConformError.new_problem(
             vow,
             vow_path,
             via,
             RegexOp.uninit_path(value_path),
             [],
             "Insufficient Data"
           )
         ]}
      end
    end

    defp conform_reducer(_vow, vow_path, via, value_path, {k, s}, {:ok, acc, [h | t] = r}) do
      if Vow.regex?(s) do
        case @protocol.conform(s, vow_path ++ [k], via, value_path, r) do
          {:ok, c, rest} -> {:ok, Map.put(acc, k, c), rest}
          {:error, problems} -> {:error, problems}
        end
      else
        case Conformable.conform(s, vow_path ++ [k], via, RegexOp.uninit_path(value_path), h) do
          {:ok, c} -> {:ok, Map.put(acc, k, c), t}
          {:error, problems} -> {:error, problems}
        end
      end
    end
  end
end
