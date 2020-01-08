defprotocol Vow.Conformable do
  @moduledoc """
  TODO
  """

  alias Vow.ConformError

  @fallback_to_any true

  @type conformed :: term

  @type result :: {:ok, conformed} | {:error, [ConformError.Problem.t()]}

  @doc """
  Given a vow and a value, return an error if the value does not match
  the vow, otherwise returns the (potentially) destructured value.

  The other parameters are for tracking composed conform calls:
    * path - the set of keys used to `Access` the current vow
    from the parent vow
    * via - the set of `Vow.Ref` navigated to get to the current vow
    * route - the set of keys used to `Access` the current value from
    the parent value
  """
  @spec conform(t, [term], [Vow.Ref.t()], [term], term) :: result
  def conform(vow, path, via, route, val)

  @doc """
  Given a vow and a conformed value, returns the original unconformed value,
  otherwise return an `Vow.UnformError`.
  """
  @spec unform(t, conformed) :: {:ok, val :: term} | {:error, Vow.UnformError.t()}
  def unform(vow, conformed_value)

  @doc """
  Returns `true` if the vow is a `Vow.RegexOperator`, otherwise returns `false`.
  """
  @spec regex?(t) :: boolean
  def regex?(vow)
end

defimpl Vow.Conformable, for: Function do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, val) when is_function(vow, 1) do
    case safe_execute(vow, val) do
      {:ok, true} ->
        {:ok, val}

      {:ok, false} ->
        {:error, [ConformError.new_problem(vow, path, via, route, val)]}

      {:ok, _} ->
        {:error,
         [
           ConformError.new_problem(
             vow,
             path,
             via,
             route,
             val,
             "Non-boolean return values are invalid"
           )
         ]}

      {:error, reason} ->
        {:error, [ConformError.new_problem(vow, path, via, route, val, reason)]}
    end
  end

  def conform(_vow, path, via, route, val) do
    {:error, [ConformError.new_problem(wrap(&is_function(&1, 1)), path, via, route, val)]}
  end

  @impl Vow.Conformable
  def unform(_vow, val) do
    {:ok, val}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false

  @spec safe_execute((term -> term), term) :: {:ok, term} | {:error, term}
  defp safe_execute(fun, val) do
    {:ok, fun.(val)}
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
  alias Vow.{ConformError, ConformError.Problem}

  @impl Vow.Conformable
  def conform(vow, path, via, route, val)
      when is_list(val) and length(vow) == length(val) do
    vow
    |> Enum.zip(val)
    |> Enum.with_index()
    |> Enum.reduce({:ok, []}, &conform_reducer(&1, &2, path, via, route))
    |> case do
      {:error, problems} -> {:error, problems}
      {:ok, conformed} -> {:ok, Enum.reverse(conformed)}
    end
  end

  def conform(vow, path, via, route, val) when is_list(val) do
    list_info = {improper_info(vow), improper_info(val)}
    conform_non_similar(list_info, vow, path, via, route, val)
  end

  def conform(_vow, path, via, route, val) do
    {:error, [ConformError.new_problem(&is_list/1, path, via, route, val)]}
  end

  @impl Vow.Conformable
  def unform(vow, val)
      when is_list(val) and length(vow) == length(val) do
    Enum.reduce(Enum.zip(vow, val), {:ok, []}, fn
      _, {:error, reason} ->
        {:error, reason}

      {v, val}, {:ok, acc} ->
        case @protocol.unform(v, val) do
          {:ok, unformed} -> {:ok, [unformed | acc]}
          {:error, reason} -> {:error, reason}
        end
    end)
  end

  def unform(vow, val) when is_list(val) do
    case {improper_info(vow), improper_info(val)} do
      {{true, n}, {true, n}} ->
        unform_improper_impl(vow, val)

      _ ->
        {:error, %Vow.UnformError{vow: vow, val: val}}
    end
  end

  def unform(vow, val) do
    {:error, %Vow.UnformError{vow: vow, val: val}}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false

  @spec conform_reducer(
          {{Vow.t(), term}, non_neg_integer},
          @protocol.result,
          [term],
          [Vow.Ref.t()],
          [term]
        ) :: @protocol.result
  defp conform_reducer({{vow, val}, i}, {:ok, acc}, path, via, route) do
    case @protocol.conform(vow, [i | path], via, [i | route], val) do
      {:error, ps} -> {:error, ps}
      {:ok, ch} -> {:ok, [ch | acc]}
    end
  end

  defp conform_reducer({{vow, val}, i}, {:error, pblms}, path, via, route) do
    case @protocol.conform(vow, [i | path], via, [i | route], val) do
      {:error, ps} -> {:error, pblms ++ ps}
      {:ok, _} -> {:error, pblms}
    end
  end

  @spec conform_non_similar({info, info}, Vow.t(), [term], [Vow.Ref.t()], [term], term) ::
          @protocol.result
        when info: {boolean, non_neg_integer}
  defp conform_non_similar({{true, n}, {true, n}}, vow, path, via, route, val) do
    conform_improper(vow, path, via, route, val, 0)
  end

  defp conform_non_similar({{false, _}, {false, _}}, vow, path, via, route, val) do
    pred = wrap(&(length(&1) == length(vow)))
    {:error, [Problem.new(pred, path, via, route, val)]}
  end

  defp conform_non_similar(_, vow, path, via, route, val) do
    pred = wrap(&compatible_form?(vow, &1))
    {:error, [Problem.new(pred, path, via, route, val)]}
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

  defp unform_improper_impl(vow, val) do
    @protocol.unform(vow, val)
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
    head = @protocol.conform(sh, [pos | path], via, [pos | route], vh)
    tail = conform_improper(st, path, via, route, vt, pos + 1)
    conform_improper_tail({head, tail})
  end

  defp conform_improper(vow, path, via, route, val, pos) do
    @protocol.conform(vow, [pos | path], via, [pos | route], val)
  end

  @spec conform_improper_tail({@protocol.result, @protocol.result}) :: @protocol.result
  defp conform_improper_tail({{:ok, ch}, {:ok, ct}}), do: {:ok, [ch | ct]}
  defp conform_improper_tail({{:error, hps}, {:error, tps}}), do: {:error, hps ++ tps}
  defp conform_improper_tail({_, {:error, ps}}), do: {:error, ps}
  defp conform_improper_tail({{:error, ps}, _}), do: {:error, ps}
end

defimpl Vow.Conformable, for: Tuple do
  @moduledoc false

  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, val) when is_tuple(val) do
    {ls, lv} = {Tuple.to_list(vow), Tuple.to_list(val)}

    case @protocol.List.conform(ls, path, via, route, lv) do
      {:ok, list} -> {:ok, List.to_tuple(list)}
      {:error, problems} -> {:error, problems}
    end
  end

  def conform(_vow, path, via, route, val) do
    {:error, [ConformError.new_problem(&is_tuple/1, path, via, route, val)]}
  end

  @impl Vow.Conformable
  def unform(vow, val) when is_tuple(val) do
    {ls, lv} = {Tuple.to_list(vow), Tuple.to_list(val)}

    case @protocol.List.unform(ls, lv) do
      {:ok, list} -> {:ok, List.to_tuple(list)}
      {:error, reason} -> {:error, reason}
    end
  end

  def unform(vow, val) do
    {:error, %Vow.UnformError{vow: vow, val: val}}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false
end

defimpl Vow.Conformable, for: Map do
  @moduledoc false

  import Vow.FunctionWrapper
  alias Vow.ConformError

  @type result :: {:ok, Vow.Conformable.conformed()} | {:error, [ConformError.Problem.t()]}

  @impl Vow.Conformable
  def conform(vow, path, via, route, val) when is_map(val) do
    Enum.reduce(
      vow,
      {:ok, val},
      conform_reducer(path, via, route, val)
    )
  end

  def conform(_vow, path, via, route, val) do
    {:error, [ConformError.new_problem(&is_map/1, path, via, route, val)]}
  end

  @impl Vow.Conformable
  def unform(vow, val) when is_map(val) do
    Enum.reduce(vow, {:ok, val}, unform_reducer(val))
  end

  def unform(vow, val) do
    {:error, %Vow.UnformError{vow: vow, val: val}}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false

  @spec conform_reducer([term], [Vow.Ref.t()], [term], map) :: ({term, Vow.t()}, result -> result)
  defp conform_reducer(path, via, route, val) do
    &conform_reducer(path, via, route, val, &1, &2)
  end

  @spec conform_reducer([term], [Vow.Ref.t()], [term], map, {term, Vow.t()}, result) :: result
  defp conform_reducer(path, via, route, val, {k, s}, {:ok, c}) do
    if Map.has_key?(val, k) do
      case @protocol.conform(s, [k | path], via, [k | route], Map.get(val, k)) do
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
           val
         )
       ]}
    end
  end

  defp conform_reducer(path, via, route, val, {k, s}, {:error, ps}) do
    if Map.has_key?(val, k) do
      case @protocol.conform(s, [k | route], via, [k | route], Map.get(val, k)) do
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
           val
         )
       ]}
    end
  end

  @spec unform_reducer(map) :: ({term, Vow.t()}, result -> result)
  defp unform_reducer(val) do
    fn x, acc -> unform_reducer(val, x, acc) end
  end

  @spec unform_reducer(map, {term, Vow.t()}, result) :: result
  defp unform_reducer(_value, _item, {:error, reason}) do
    {:error, reason}
  end

  defp unform_reducer(val, {k, v}, {:ok, acc}) do
    if Map.has_key?(val, k) do
      case @protocol.unform(v, Map.get(val, k)) do
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
  def conform(vow, path, via, route, %MapSet{} = val) do
    if MapSet.subset?(val, vow) do
      {:ok, val}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&MapSet.subset?(&1, vow)),
           path,
           via,
           route,
           val
         )
       ]}
    end
  end

  def conform(vow, path, via, route, val) do
    if MapSet.member?(vow, val) do
      {:ok, val}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&MapSet.member?(vow, &1)),
           path,
           via,
           route,
           val
         )
       ]}
    end
  end

  @impl Vow.Conformable
  def unform(_vow, val) do
    {:ok, val}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false
end

defimpl Vow.Conformable, for: Regex do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(vow, path, via, route, val) when is_bitstring(val) do
    if Regex.match?(vow, val) do
      {:ok, val}
    else
      {:error,
       [
         ConformError.new_problem(
           wrap(&Regex.match?(vow, &1)),
           path,
           via,
           route,
           val
         )
       ]}
    end
  end

  def conform(_vow, path, via, route, val) do
    {:error, [ConformError.new_problem(&is_bitstring/1, path, via, route, val)]}
  end

  @impl Vow.Conformable
  def unform(_vow, val) do
    {:ok, val}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false
end

defimpl Vow.Conformable, for: Range do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.{ConformError, ConformError.Problem}

  @impl Vow.Conformable
  def conform(vow, path, via, route, _.._ = val) do
    member = {Enum.member?(vow, val.first), Enum.member?(vow, val.last)}
    conform_range(member, vow, path, via, route, val)
  end

  def conform(vow, path, via, route, val) when is_integer(val) do
    if Enum.member?(vow, val) do
      {:ok, val}
    else
      pred = wrap(&Enum.member?(vow, &1))
      {:error, [Problem.new(pred, path, via, route, val)]}
    end
  end

  def conform(_vow, path, via, route, val) do
    {:error, [ConformError.new_problem(&is_integer/1, path, via, route, val)]}
  end

  @impl Vow.Conformable
  def unform(_vow, val) do
    {:ok, val}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false

  @spec conform_range({boolean, boolean}, Vow.t(), [term], [Vow.Ref.t()], [term], term) ::
          Vow.Conformable.result()
  def conform_range({true, true}, _vow, _path, _via, _route, val) do
    {:ok, val}
  end

  def conform_range({true, false}, vow, path, via, route, val) do
    pred = wrap(&Enum.member?(vow, &1.last))
    {:error, [Problem.new(pred, path, via, route, val)]}
  end

  def conform_range({false, true}, vow, path, via, route, val) do
    pred = wrap(&Enum.member?(vow, &1.last))
    {:error, [Problem.new(pred, path, via, route, val)]}
  end

  def conform_range({false, false}, vow, path, via, route, val) do
    pred1 = wrap(&Enum.member?(vow, &1.first))
    pred2 = wrap(&Enum.member?(vow, &1.last))

    {:error,
     [
       Problem.new(pred1, path, via, route, val),
       Problem.new(pred2, path, via, route, val)
     ]}
  end
end

defimpl Vow.Conformable, for: Date.Range do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  import Vow.Conformable.Range, only: [conform_range: 6]
  alias Vow.ConformError.Problem

  @impl Vow.Conformable
  def conform(vow, path, via, route, %Date.Range{} = val) do
    member = {Enum.member?(vow, val.first), Enum.member?(vow, val.last)}
    conform_range(member, vow, path, via, route, val)
  end

  def conform(vow, path, via, route, %Date{} = val) do
    if Enum.member?(vow, val) do
      {:ok, val}
    else
      pred = wrap(&Enum.member?(vow, &1))
      {:error, [Problem.new(pred, path, via, route, val)]}
    end
  end

  def conform(_vow, path, via, route, val) do
    pred = wrap(&match?(%Date{}, &1))
    {:error, [Problem.new(pred, path, via, route, val)]}
  end

  @impl Vow.Conformable
  def unform(_vow, val) do
    {:ok, val}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false
end

defimpl Vow.Conformable, for: Any do
  @moduledoc false

  import Vow.FunctionWrapper, only: [wrap: 1]
  alias Vow.ConformError

  @impl Vow.Conformable
  def conform(%{__struct__: mod} = struct, path, via, route, %{__struct__: mod} = val) do
    case @protocol.Map.conform(
           Map.delete(struct, :__struct__),
           path,
           via,
           route,
           Map.delete(val, :__struct__)
         ) do
      {:ok, conformed} -> {:ok, Map.put(conformed, :__struct__, mod)}
      {:error, reason} -> {:error, reason}
    end
  end

  def conform(%{__struct__: _} = vow, path, via, route, %{__struct__: _} = val) do
    problem =
      ConformError.new_problem(
        wrap(&(&1.__struct__ == vow.__struct__)),
        path,
        via,
        route,
        val
      )

    case @protocol.Map.conform(
           Map.delete(vow, :__struct__),
           path,
           via,
           route,
           Map.delete(val, :__struct__)
         ) do
      {:ok, _conformed} -> {:error, [problem]}
      {:error, problems} -> {:error, [problem | problems]}
    end
  end

  def conform(%{__struct__: _}, path, via, route, val) do
    {:error,
     [
       ConformError.new_problem(
         wrap(&Map.has_key?(&1, :__struct__)),
         path,
         via,
         route,
         val
       )
     ]}
  end

  def conform(vow, path, via, route, val) do
    if vow == val do
      {:ok, val}
    else
      {:error, [ConformError.new_problem(wrap(&(&1 == vow)), path, via, route, val)]}
    end
  end

  @impl Vow.Conformable
  def unform(%{__struct__: mod} = vow, %{__struct__: mod} = val) do
    case @protocol.Map.unform(Map.delete(vow, :__struct__), Map.delete(val, :__struct__)) do
      {:error, reason} -> {:error, reason}
      {:ok, unformed} -> {:ok, Map.put(unformed, :__struct__, mod)}
    end
  end

  def unform(%{__struct__: _} = vow, val) do
    {:error, %Vow.UnformError{vow: vow, val: val}}
  end

  def unform(_vow, val) do
    {:ok, val}
  end

  @impl Vow.Conformable
  def regex?(_vow), do: false
end
