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
  def conform(vow, path, via, route, value)

  @doc """
  """
  @spec unform(t, conformed) :: {:ok, value :: term} | {:error, Vow.UnformError.t()}
  def unform(vow, conformed_value)
end

defimpl Vow.Conformable, for: Function do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, value) when is_function(vow, 1) do
    case safe_execute(vow, value) do
      {:ok, true} ->
        {:ok, value}

      {:ok, false} ->
        {:error, [ConformError.new_problem(vow, path, via, route, value)]}

      {:ok, _} ->
        {:error,
         [
           ConformError.new_problem(
             vow,
             path,
             via,
             route,
             value,
             "Non-boolean return values are invalid"
           )
         ]}

      {:error, reason} ->
        {:error, [ConformError.new_problem(vow, path, via, route, value, reason)]}
    end
  end

  def conform(_vow, path, via, route, value) do
    {:error,
     [ConformError.new_problem(wrap(&is_function(&1, 1)), path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(_vow, value), do: {:ok, value}

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

  import Vow.FunctionWrapper, only: [wrap: 1]
  import Vow.Utils, only: [compatible_form?: 2, improper_info: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, value)
      when is_list(value) and length(vow) == length(value) do
    vow
    |> Enum.zip(value)
    |> Enum.reduce({:ok, [], [], 0}, fn
      {s, v}, {:ok, t, _, i} ->
        case @protocol.conform(s, [i|path], via, [i|route], v) do
          {:ok, h} -> {:ok, [h | t], [], i + 1}
          {:error, ps} -> {:error, nil, ps, i + 1}
        end

      {s, v}, {:error, _, pblms, i} ->
        case @protocol.conform(s, [i|path], via, [i|route], v) do
          {:ok, _} -> {:error, nil, pblms, i + 1}
          {:error, ps} -> {:error, nil, pblms ++ ps, i + 1}
        end
    end)
    |> case do
      {:ok, conformed, _, _} -> {:ok, Enum.reverse(conformed)}
      {:error, _, problems, _} -> {:error, problems}
    end
  end

  def conform(vow, path, via, route, value) when is_list(value) do
    case {improper_info(vow), improper_info(value)} do
      {{true, n}, {true, n}} ->
        conform_improper(vow, path, via, route, value, 0)

      {{false, _}, {false, _}} ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&(length(&1) == length(vow))),
             path,
             via,
             route,
             value
           )
         ]}

      _ ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&compatible_form?(vow, &1)),
             path,
             via,
             route,
             value
           )
         ]}
    end
  end

  def conform(_vow, path, via, route, value) do
    {:error, [ConformError.new_problem(&is_list/1, path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(vow, value)
      when is_list(value) and length(vow) == length(value) do
    Enum.reduce(Enum.zip(vow, value), {:ok, []}, fn
      _, {:error, reason} ->
        {:error, reason}

      {v, val}, {:ok, acc} ->
        case @protocol.unform(v, val) do
          {:ok, unformed} -> {:ok, [unformed|acc]}
          {:error, reason} -> {:error, reason}
        end
    end)
  end

  def unform(vow, value) when is_list(value) do
    case {improper_info(vow), improper_info(value)} do
      {{true, n}, {true, n}} ->
        unform_improper_impl(vow, value)

      _ ->
        {:error, %Vow.UnformError{vow: vow, value: value}}
    end
  end

  def unform(vow, value) do
    {:error, %Vow.UnformError{vow: vow, value: value}}
  end

  @spec unform_improper_impl(
          nonempty_improper_list(Vow.t(), Vow.t()),
          nonempty_improper_list(term, term)
        ) ::
          nonempty_improper_list(term, term) | term
  defp unform_improper_impl([hv | tv], [hval | tval]) do
    with {:ok, uh} <- @protocol.unform(hv, hval),
         {:ok, ut} <- unform_improper_impl(tv, tval) do
      {:ok, [uh | ut]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp unform_improper_impl(vow, value) do
    @protocol.unform(vow, value)
  end

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
  defp conform_improper([sh | st], path, via, route, [vh | vt], pos) do
    head = @protocol.conform(sh, [pos|path], via, [pos|route], vh)

    case {head, conform_improper(st, path, via, route, vt, pos + 1)} do
      {{:ok, ch}, {:ok, ct}} -> {:ok, [ch | ct]}
      {{:error, hps}, {:error, tps}} -> {:error, hps ++ tps}
      {_, {:error, ps}} -> {:error, ps}
      {{:error, ps}, _} -> {:error, ps}
    end
  end

  defp conform_improper(vow, path, via, route, value, pos) do
    @protocol.conform(
      vow,
      [pos|path],
      via,
      [pos|route],
      value
    )
  end
end

defimpl Vow.Conformable, for: Tuple do
  @moduledoc false

  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, value) when is_tuple(value) do
    {ls, lv} = {Tuple.to_list(vow), Tuple.to_list(value)}

    case @protocol.List.conform(ls, path, via, route, lv) do
      {:ok, list} -> {:ok, List.to_tuple(list)}
      {:error, problems} -> {:error, problems}
    end
  end

  def conform(_vow, path, via, route, value) do
    {:error, [ConformError.new_problem(&is_tuple/1, path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(vow, value) when is_tuple(value) do
    {ls, lv} = {Tuple.to_list(vow), Tuple.to_list(value)}

    case @protocol.List.unform(ls, lv) do
      {:ok, list} -> {:ok, List.to_tuple(list)}
      {:error, reason} -> {:error, reason}
    end
  end

  def unform(vow, value) do
    {:error, %Vow.UnformError{vow: vow, value: value}}
  end
end

defimpl Vow.Conformable, for: Map do
  @moduledoc false

  import Vow.FunctionWrapper
  alias Vow.ConformError

  @type result :: {:ok, Vow.Conformable.conformed()} | {:error, [ConformError.Problem.t()]}

  @impl Vow.Conformable
  def conform(vow, path, via, route, value) when is_map(value) do
    Enum.reduce(
      vow,
      {:ok, value},
      conform_reducer(path, via, route, value)
    )
  end

  def conform(_vow, path, via, route, value) do
    {:error, [ConformError.new_problem(&is_map/1, path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(vow, value) when is_map(value) do
    Enum.reduce(vow, {:ok, value}, unform_reducer(value))
  end

  def unform(vow, value) do
    {:error, %Vow.UnformError{vow: vow, value: value}}
  end

  @spec conform_reducer([term], [Vow.Ref.t()], [term], map) :: ({term, Vow.t()}, result -> result)
  defp conform_reducer(path, via, route, value) do
    &conform_reducer(path, via, route, value, &1, &2)
  end

  @spec conform_reducer([term], [Vow.Ref.t()], [term], map, {term, Vow.t()}, result) :: result
  defp conform_reducer(path, via, route, value, {k, s}, {:ok, c}) do
    if Map.has_key?(value, k) do
      case @protocol.conform(s, [k|path], via, [k|route], Map.get(value, k)) do
        {:ok, conformed} -> {:ok, Map.put(c, k, conformed)}
        {:error, problems} -> {:error, problems}
      end
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&Map.has_key?(&1, k), k: k),
           path,
           via,
           route,
           value
         )
       ]}
    end
  end

  defp conform_reducer(path, via, route, value, {k, s}, {:error, ps}) do
    if Map.has_key?(value, k) do
      case @protocol.conform(s, [k | route], via, [k | route], Map.get(value, k)) do
        {:ok, _conformed} -> {:error, ps}
        {:error, problems} -> {:error, ps ++ problems}
      end
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&Map.has_key?(&1, k), k: k),
           path,
           via,
           route,
           value
         )
       ]}
    end
  end

  @spec unform_reducer(map) :: ({term, Vow.t()}, result -> result)
  defp unform_reducer(value) do
    fn x, acc -> unform_reducer(value, x, acc) end
  end

  @spec unform_reducer(map, {term, Vow.t()}, result) :: result
  defp unform_reducer(_value, _item, {:error, reason}), do: {:error, reason}

  defp unform_reducer(value, {k, v}, {:ok, acc}) do
    if Map.has_key?(value, k) do
      case @protocol.unform(v, Map.get(value, k)) do
        {:ok, unformed} -> {:ok, Map.put(acc, k, unformed)}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end

defimpl Vow.Conformable, for: MapSet do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, %MapSet{} = value) do
    if MapSet.subset?(value, vow) do
      {:ok, value}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&MapSet.subset?(&1, vow)),
           path,
           via,
           route,
           value
         )
       ]}
    end
  end

  def conform(vow, path, via, route, value) do
    if MapSet.member?(vow, value) do
      {:ok, value}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&MapSet.member?(vow, &1)),
           path,
           via,
           route,
           value
         )
       ]}
    end
  end

  @impl Vow.Conformable
  def unform(_vow, value), do: {:ok, value}
end

defimpl Vow.Conformable, for: Regex do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, value) when is_bitstring(value) do
    if Regex.match?(vow, value) do
      {:ok, value}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&Regex.match?(vow, &1)),
           path,
           via,
           route,
           value
         )
       ]}
    end
  end

  def conform(_vow, path, via, route, value) do
    {:error, [ConformError.new_problem(&is_bitstring/1, path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(_vow, value), do: {:ok, value}
end

defimpl Vow.Conformable, for: Range do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, _.._ = value) do
    case {Enum.member?(vow, value.first), Enum.member?(vow, value.last)} do
      {true, true} ->
        {:ok, value}

      {true, false} ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.last)),
             path,
             via,
             route,
             value
           )
         ]}

      {false, true} ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.first)),
             path,
             via,
             route,
             value
           )
         ]}

      {false, false} ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.first)),
             path,
             via,
             route,
             value
           ),
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.last)),
             path,
             via,
             route,
             value
           )
         ]}
    end
  end

  def conform(vow, path, via, route, value) when is_integer(value) do
    if Enum.member?(vow, value) do
      {:ok, value}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&Enum.member?(vow, &1)),
           path,
           via,
           route,
           value
         )
       ]}
    end
  end

  def conform(_vow, path, via, route, value) do
    {:error, [ConformError.new_problem(&is_integer/1, path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(_vow, value), do: {:ok, value}
end

defimpl Vow.Conformable, for: Date.Range do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, %Date.Range{} = value) do
    case {Enum.member?(vow, value.first), Enum.member?(vow, value.last)} do
      {true, true} ->
        {:ok, value}

      {true, false} ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.last)),
             path,
             via,
             route,
             value
           )
         ]}

      {false, true} ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.first)),
             path,
             via,
             route,
             value
           )
         ]}

      {false, false} ->
        {:error,
         [
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.first)),
             path,
             via,
             route,
             value
           ),
           ConformError.new_problem(
             wrap(&Enum.member?(vow, &1.last)),
             path,
             via,
             route,
             value
           )
         ]}
    end
  end

  def conform(vow, path, via, route, %Date{} = value) do
    if Enum.member?(vow, value) do
      {:ok, value}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&Enum.member?(vow, &1)),
           path,
           via,
           route,
           value
         )
       ]}
    end
  end

  def conform(_vow, path, via, route, value) do
    {:error,
     [ConformError.new_problem(wrap(&match?(%Date{}, &1)), path, via, route, value)]}
  end

  @impl Vow.Conformable
  def unform(_vow, value), do: {:ok, value}
end

defimpl Vow.Conformable, for: Any do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(%{__struct__: mod} = struct, path, via, route, %{__struct__: mod} = value) do
    case @protocol.Map.conform(
           Map.delete(struct, :__struct__),
           path,
           via,
           route,
           Map.delete(value, :__struct__)
         ) do
      {:ok, conformed} -> {:ok, Map.put(conformed, :__struct__, mod)}
      {:error, reason} -> {:error, reason}
    end
  end

  def conform(%{__struct__: _} = vow, path, via, route, %{__struct__: _} = value) do
    problem =
      ConformError.new_problem(
        wrap(&(&1.__struct__ == vow.__struct__)),
        path,
        via,
        route,
        value
      )

    case @protocol.Map.conform(
           Map.delete(vow, :__struct__),
           path,
           via,
           route,
           Map.delete(value, :__struct__)
         ) do
      {:ok, _conformed} -> {:error, [problem]}
      {:error, problems} -> {:error, [problem | problems]}
    end
  end

  def conform(%{__struct__: _}, path, via, route, value) do
    {:error,
     [
       ConformError.new_problem(
         wrap(&Map.has_key?(&1, :__struct__)),
         path,
         via,
         route,
         value
       )
     ]}
  end

  def conform(vow, path, via, route, value) do
    if vow == value do
      {:ok, value}
    else
      {:error, [ConformError.new_problem(wrap(&(&1 == vow)), path, via, route, value)]}
    end
  end

  @impl Vow.Conformable
  def unform(%{__struct__: mod} = vow, %{__struct__: mod} = value) do
    case @protocol.Map.unform(Map.delete(vow, :__struct__), Map.delete(value, :__struct__)) do
      {:error, reason} -> {:error, reason}
      {:ok, unformed} -> {:ok, Map.put(unformed, :__struct__, mod)}
    end
  end

  def unform(%{__struct__: _} = vow, value) do
    {:error, %Vow.UnformError{vow: vow, value: value}}
  end

  def unform(_vow, value), do: {:ok, value}
end
