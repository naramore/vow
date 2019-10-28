defmodule Vow.DuplicateNameError do
  @moduledoc false

  defexception [:spec]

  @type t :: %__MODULE__{
          spec: Vow.t()
        }

  @impl Exception
  def message(%__MODULE__{spec: spec}) do
    "Duplicate sub-spec names are not allowed in #{spec.__struct__}"
  end
end

defmodule Vow.Cat do
  @moduledoc false

  defstruct [:specs]

  @type t :: %__MODULE__{
          specs: [{atom, Vow.t()}, ...]
        }

  @spec new([{atom, Vow.t()}, ...]) :: t | no_return
  def new(named_specs) do
    spec = %__MODULE__{specs: named_specs}

    if unique_keys?(named_specs) do
      spec
    else
      raise %Vow.DuplicateNameError{spec: spec}
    end
  end

  @spec unique_keys?([{atom, Vow.t()}]) :: boolean
  def unique_keys?(named_specs) do
    {keys, _} = Enum.unzip(named_specs)
    unique_keys = Enum.uniq(keys)
    length(keys) == length(unique_keys)
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    import Vow.Conformable.Vow.List, only: [proper_list?: 1]
    alias Vow.{Conformable, ConformError, RegexOp, RegexOperator}

    @type result ::
            {:ok, RegexOperator.conformed(), RegexOperator.rest()}
            | {:error, [ConformError.Problem.t()]}

    def conform(%@for{specs: specs} = spec, spec_path, via, value_path, value)
        when is_list(value) and length(value) >= 0 do
      Enum.reduce(
        specs,
        {:ok, %{}, value},
        conform_reducer(spec, spec_path, via, value_path)
      )
    end

    def conform(_spec, spec_path, via, value_path, value) when is_list(value) do
      {:error,
       [
         ConformError.new_problem(
           &proper_list?/1,
           spec_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    def conform(_spec, spec_path, via, value_path, value) do
      {:error,
       [
         ConformError.new_problem(
           &is_list/1,
           spec_path,
           via,
           RegexOp.uninit_path(value_path),
           value
         )
       ]}
    end

    @spec conform_reducer(Vow.t(), [term], [Vow.Ref.t()], [term]) ::
            ({atom, Vow.t()}, result -> result)
    defp conform_reducer(spec, spec_path, via, value_path) do
      &conform_reducer(spec, spec_path, via, value_path, &1, &2)
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

    defp conform_reducer(spec, spec_path, via, value_path, {k, s}, {:ok, acc, []}) do
      if Vow.regex?(s) do
        case @protocol.conform(s, spec_path ++ [k], via, value_path, []) do
          {:ok, c, rest} -> {:ok, Map.put(acc, k, c), rest}
          {:error, problems} -> {:error, problems}
        end
      else
        {:error,
         [
           ConformError.new_problem(
             spec,
             spec_path,
             via,
             RegexOp.uninit_path(value_path),
             [],
             "Insufficient Data"
           )
         ]}
      end
    end

    defp conform_reducer(_spec, spec_path, via, value_path, {k, s}, {:ok, acc, [h | t] = r}) do
      if Vow.regex?(s) do
        case @protocol.conform(s, spec_path ++ [k], via, value_path, r) do
          {:ok, c, rest} -> {:ok, Map.put(acc, k, c), rest}
          {:error, problems} -> {:error, problems}
        end
      else
        case Conformable.conform(s, spec_path ++ [k], via, RegexOp.uninit_path(value_path), h) do
          {:ok, c} -> {:ok, Map.put(acc, k, c), t}
          {:error, problems} -> {:error, problems}
        end
      end
    end
  end
end
