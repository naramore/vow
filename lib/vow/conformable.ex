defprotocol Vow.Conformable do
  @moduledoc """
  TODO
  """

  alias Vow.ConformError

  @fallback_to_any true

  @type conformed :: term

  @doc """
  """
  @spec conform(t, [term], [Vow.Ref.t()], [term], term) ::
          {:ok, conformed} | {:error, [ConformError.Problem.t()]}
  def conform(spec, spec_path, via, value_path, value)
end

defimpl Vow.Conformable, for: Function do
  @moduledoc false

  import Vow.Func, only: [f: 1]
  alias Vow.ConformError

  def conform(fun, spec_path, via, value_path, value) when is_function(fun, 1) do
    case safe_execute(fun, value) do
      {:ok, true} -> {:ok, value}
      _ -> {:error, [ConformError.new_problem(fun, spec_path, via, value_path, value)]}
    end
  end

  def conform(_fun, spec_path, via, value_path, value) do
    {:error,
     [ConformError.new_problem(f(&is_function(&1, 1)), spec_path, via, value_path, value)]}
  end

  @spec safe_execute((term -> term), term) :: {:ok, term} | {:error, term}
  defp safe_execute(fun, value) do
    {:ok, fun.(value)}
  rescue
    reason -> {:error, reason}
  catch
    :exit, reason -> {:error, {:exit, reason}}
    caught -> {:error, caught}
  end
end

defimpl Vow.Conformable, for: List do
  @moduledoc false

  use Vow.Func
  alias Vow.ConformError

  def conform(spec, spec_path, via, value_path, value)
      when is_list(value) and length(spec) == length(value) do
    Enum.zip(spec, value)
    |> Enum.reduce({:ok, [], [], 0}, fn
      {s, v}, {:ok, t, _, i} ->
        case @protocol.conform(s, spec_path ++ [i], via, value_path ++ [i], v) do
          {:ok, h} -> {:ok, [h | t], [], i + 1}
          {:error, ps} -> {:error, nil, ps, i + 1}
        end

      {s, v}, {:error, _, pblms, i} ->
        case @protocol.conform(s, spec_path ++ [i], via, value_path ++ [i], v) do
          {:ok, _} -> {:error, nil, pblms, i + 1}
          {:error, ps} -> {:error, nil, pblms ++ ps, i + 1}
        end
    end)
    |> case do
      {:ok, conformed, _, _} -> {:ok, Enum.reverse(conformed)}
      {:error, _, problems, _} -> {:error, problems}
    end
  end

  def conform(spec, spec_path, via, value_path, value) when is_list(value) do
    case {improper_info(spec), improper_info(value)} do
      {{true, n}, {true, n}} ->
        conform_improper(spec, spec_path, via, value_path, value, 0)

      {{false, _}, {false, _}} ->
        {:error,
         [
           ConformError.new_problem(
             f(&(length(&1) == length(spec))),
             spec_path,
             via,
             value_path,
             value
           )
         ]}

      _ ->
        {:error,
         [
           ConformError.new_problem(
             f(&compatible_form?(spec, &1)),
             spec_path,
             via,
             value_path,
             value
           )
         ]}
    end
  end

  def conform(_spec, spec_path, via, value_path, value) do
    {:error, [ConformError.new_problem(&is_list/1, spec_path, via, value_path, value)]}
  end

  @spec compatible_form?(list, term) :: boolean
  def compatible_form?(list, value) do
    case {improper_info(list), improper_info(value)} do
      {{true, n}, {true, n}} -> true
      {{false, n}, {false, n}} -> true
      _ -> false
    end
  end

  @spec improper_info(list) :: {boolean, non_neg_integer}
  defp improper_info(list, n \\ 0)
  defp improper_info([], n), do: {false, n}
  defp improper_info([_ | t], n) when is_list(t), do: improper_info(t, n + 1)
  defp improper_info(_, n), do: {true, n}

  @type position :: non_neg_integer | :__improper_tail__

  @spec conform_improper(
          nonempty_improper_list(Vow.t(), Vow.t()) | Vow.t(),
          [term],
          [Vow.Ref.t()],
          [term],
          nonempty_improper_list(term, term) | term,
          position
        ) ::
          {:ok, term} | {:error, [ConformError.Problem.t()]}
  defp conform_improper([sh | st], spec_path, via, value_path, [vh | vt], pos) do
    head = @protocol.conform(sh, spec_path ++ [pos], via, value_path ++ [pos], vh)

    case {head, conform_improper(st, spec_path, via, value_path, vt, pos + 1)} do
      {{:ok, ch}, {:ok, ct}} -> {:ok, [ch | ct]}
      {{:error, hps}, {:error, tps}} -> {:error, hps ++ tps}
      {_, {:error, ps}} -> {:error, ps}
      {{:error, ps}, _} -> {:error, ps}
    end
  end

  defp conform_improper(spec, spec_path, via, value_path, value, _pos) do
    @protocol.conform(
      spec,
      spec_path ++ [:__improper_tail__],
      via,
      value_path ++ [:__improper_tail__],
      value
    )
  end
end

defimpl Vow.Conformable, for: Tuple do
  @moduledoc false

  alias Vow.ConformError

  def conform(spec, spec_path, via, value_path, value) when is_tuple(value) do
    {ls, lv} = {Tuple.to_list(spec), Tuple.to_list(value)}

    case @protocol.List.conform(ls, spec_path, via, value_path, lv) do
      {:ok, list} -> {:ok, List.to_tuple(list)}
      {:error, problems} -> {:error, problems}
    end
  end

  def conform(_spec, spec_path, via, value_path, value) do
    {:error, [ConformError.new_problem(&is_tuple/1, spec_path, via, value_path, value)]}
  end
end

defimpl Vow.Conformable, for: Map do
  @moduledoc false

  use Vow.Func
  alias Vow.ConformError

  def conform(spec, spec_path, via, value_path, value)
      when is_map(value) and map_size(spec) == map_size(value) do
    if all_keys?(spec, value) do
      {keys, list_spec, list_value} = unzip_samesize(spec, value)

      case @protocol.List.conform(list_spec, spec_path, via, value_path, list_value) do
        {:ok, conformed} ->
          {:ok, Enum.zip(keys, conformed) |> Enum.into(%{})}

        {:error, problems} ->
          {:error, keyize_problems(problems, keys, spec_path, value_path)}
      end
    else
      {:error,
       [
         ConformError.new_problem(
           spec,
           spec_path,
           via,
           value_path,
           value,
           "Key Mismatch b/t spec and value"
         )
       ]}
    end
  end

  def conform(spec, spec_path, via, value_path, value) when is_map(value) do
    {:error,
     [
       ConformError.new_problem(
         f(&(map_size(&1) == map_size(spec))),
         spec_path,
         via,
         value_path,
         value
       )
     ]}
  end

  def conform(_spec, spec_path, via, value_path, value) do
    {:error, [ConformError.new_problem(&is_map/1, spec_path, via, value_path, value)]}
  end

  @spec all_keys?(map, map) :: boolean
  def all_keys?(map1, map2) do
    MapSet.new(Map.keys(map1)) == MapSet.new(Map.keys(map2))
  end

  @spec keyize_problems([ConformError.Problem.t()], [term], [term], [term]) :: [
          ConformError.Problem.t()
        ]
  def keyize_problems([], _keys, _spec_path, _value_path), do: []

  def keyize_problems(problems, keys, spec_path, value_path) do
    si = length(spec_path)
    vi = length(value_path)

    Enum.map(problems, fn prob ->
      prob
      |> update_in([:spec_path, Access.at(si)], &Enum.at(keys, &1))
      |> update_in([:value_path, Access.at(vi)], &Enum.at(keys, &1))
    end)
  end

  @spec unzip_samesize(map, map) :: {keys :: list, values1 :: list, values2 :: list}
  def unzip_samesize(map1, map2)
      when map_size(map1) == map_size(map2) do
    keys = Map.keys(map1)

    {values1, values2} =
      Enum.reduce(keys, {[], []}, fn k, {values1, values2} ->
        {[Map.get(map1, k) | values1], [Map.get(map2, k) | values2]}
      end)

    {keys, Enum.reverse(values1), Enum.reverse(values2)}
  end
end

defimpl Vow.Conformable, for: MapSet do
  @moduledoc false

  use Vow.Func
  alias Vow.ConformError

  def conform(spec, spec_path, via, value_path, %MapSet{} = value) do
    if MapSet.subset?(value, spec) do
      {:ok, value}
    else
      {:error,
       [ConformError.new_problem(f(&MapSet.subset?(&1, spec)), spec_path, via, value_path, value)]}
    end
  end

  def conform(spec, spec_path, via, value_path, value) do
    if MapSet.member?(spec, value) do
      {:ok, value}
    else
      {:error,
       [ConformError.new_problem(f(&MapSet.member?(spec, &1)), spec_path, via, value_path, value)]}
    end
  end
end

defimpl Vow.Conformable, for: Regex do
  @moduledoc false

  use Vow.Func
  alias Vow.ConformError

  def conform(spec, spec_path, via, value_path, value) when is_bitstring(value) do
    if Regex.match?(spec, value) do
      {:ok, value}
    else
      {:error,
       [ConformError.new_problem(f(&Regex.match?(spec, &1)), spec_path, via, value_path, value)]}
    end
  end

  def conform(_spec, spec_path, via, value_path, value) do
    {:error, [ConformError.new_problem(&is_bitstring/1, spec_path, via, value_path, value)]}
  end
end

defimpl Vow.Conformable, for: Range do
  @moduledoc false

  use Vow.Func
  alias Vow.ConformError

  def conform(range, spec_path, via, value_path, _.._ = value) do
    {
      Enum.member?(range, value.first),
      Enum.member?(range, value.last)
    }
    |> case do
      {true, true} ->
        {:ok, value}

      {true, false} ->
        {:error,
         [
           ConformError.new_problem(
             f(&Enum.member?(range, &1.last)),
             spec_path,
             via,
             value_path,
             value
           )
         ]}

      {false, true} ->
        {:error,
         [
           ConformError.new_problem(
             f(&Enum.member?(range, &1.first)),
             spec_path,
             via,
             value_path,
             value
           )
         ]}

      {false, false} ->
        {:error,
         [
           ConformError.new_problem(
             f(&Enum.member?(range, &1.first)),
             spec_path,
             via,
             value_path,
             value
           ),
           ConformError.new_problem(
             f(&Enum.member?(range, &1.last)),
             spec_path,
             via,
             value_path,
             value
           )
         ]}
    end
  end

  def conform(range, spec_path, via, value_path, value) when is_integer(value) do
    if Enum.member?(range, value) do
      {:ok, value}
    else
      {:error,
       [ConformError.new_problem(f(&Enum.member?(range, &1)), spec_path, via, value_path, value)]}
    end
  end

  def conform(_spec, spec_path, via, value_path, value) do
    {:error, [ConformError.new_problem(&is_integer/1, spec_path, via, value_path, value)]}
  end
end

defimpl Vow.Conformable, for: Date.Range do
  @moduledoc false

  use Vow.Func
  alias Vow.ConformError

  def conform(date_range, spec_path, via, value_path, %Date.Range{} = value) do
    {
      Enum.member?(date_range, value.first),
      Enum.member?(date_range, value.last)
    }
    |> case do
      {true, true} ->
        {:ok, value}

      {true, false} ->
        {:error,
         [
           ConformError.new_problem(
             f(&Enum.member?(date_range, &1.last)),
             spec_path,
             via,
             value_path,
             value
           )
         ]}

      {false, true} ->
        {:error,
         [
           ConformError.new_problem(
             f(&Enum.member?(date_range, &1.first)),
             spec_path,
             via,
             value_path,
             value
           )
         ]}

      {false, false} ->
        {:error,
         [
           ConformError.new_problem(
             f(&Enum.member?(date_range, &1.first)),
             spec_path,
             via,
             value_path,
             value
           ),
           ConformError.new_problem(
             f(&Enum.member?(date_range, &1.last)),
             spec_path,
             via,
             value_path,
             value
           )
         ]}
    end
  end

  def conform(date_range, spec_path, via, value_path, %Date{} = value) do
    if Enum.member?(date_range, value) do
      {:ok, value}
    else
      {:error,
       [
         ConformError.new_problem(
           f(&Enum.member?(date_range, &1)),
           spec_path,
           via,
           value_path,
           value
         )
       ]}
    end
  end

  def conform(_spec, spec_path, via, value_path, value) do
    {:error,
     [ConformError.new_problem(f(&match?(%Date{}, &1)), spec_path, via, value_path, value)]}
  end
end

defimpl Vow.Conformable, for: Any do
  @moduledoc false

  use Vow.Func
  alias Vow.ConformError

  def conform(%{__struct__: mod} = struct, spec_path, via, value_path, %{__struct__: mod} = value) do
    case @protocol.Map.conform(
           Map.delete(struct, :__struct__),
           spec_path,
           via,
           value_path,
           Map.delete(value, :__struct__)
         ) do
      {:ok, conformed} -> {:ok, Map.put(conformed, :__struct__, mod)}
      {:error, reason} -> {:error, reason}
    end
  end

  def conform(%{__struct__: _} = spec, spec_path, via, value_path, %{__struct__: _} = value) do
    problem =
      ConformError.new_problem(
        f(&(&1.__struct__ == spec.__struct__)),
        spec_path,
        via,
        value_path,
        value
      )

    case @protocol.Map.conform(
           Map.delete(spec, :__struct__),
           spec_path,
           via,
           value_path,
           Map.delete(value, :__struct__)
         ) do
      {:ok, _conformed} -> {:error, [problem]}
      {:error, problems} -> {:error, [problem | problems]}
    end
  end

  def conform(%{__struct__: _}, spec_path, via, value_path, value) do
    {:error,
     [
       ConformError.new_problem(
         f(&Map.has_key?(&1, :__struct__)),
         spec_path,
         via,
         value_path,
         value
       )
     ]}
  end

  def conform(any, spec_path, via, value_path, value) do
    if any == value do
      {:ok, value}
    else
      {:error, [ConformError.new_problem(:==, spec_path, via, value_path, value)]}
    end
  end
end
