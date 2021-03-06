defmodule Vow.Keys do
  @moduledoc false
  @behaviour Access

  defstruct required: [],
            optional: [],
            regex?: false

  @type t :: %__MODULE__{
          required: [Vow.vow_ref_expr()],
          optional: [Vow.vow_ref_expr()],
          regex?: boolean
        }

  @spec new([Vow.vow_ref_expr()], [Vow.vow_ref_expr()], module | nil, boolean) :: t | no_return
  def new(required, optional, default_module \\ nil, regex? \\ false) do
    required = update_keys(required, default_module)
    optional = update_keys(optional, default_module)

    case check_keys(required ++ optional) do
      {_, [_ | _] = dups} ->
        raise %Vow.DuplicateKeyError{duplicates: dups}

      _ ->
        %__MODULE__{
          required: required,
          optional: optional,
          regex?: regex?
        }
    end
  end

  @impl Access
  def fetch(%__MODULE__{} = vow, key) do
    case find_key(vow, key) do
      {ref, _, _} -> Access.fetch(ref, key)
      _ -> :error
    end
  end

  @impl Access
  def get_and_update(%__MODULE__{} = vow, key, fun) do
    case find_key(vow, key) do
      {_, k, path} -> Vow.get_and_update_in(vow, [k | path], fun)
      _ -> {nil, vow}
    end
  end

  @impl Access
  def pop(%__MODULE__{} = vow, key) do
    case find_key(vow, key) do
      {_, k, path} -> Vow.pop_in(vow, [k | path])
      _ -> {nil, vow}
    end
  end

  @spec check_keys([Vow.vow_ref_expr()] | Vow.vow_ref_expr(), {[atom], [atom]}) ::
          {[atom], [atom]}
  defp check_keys(keys, acc \\ {[], []})

  defp check_keys([], acc) do
    acc
  end

  defp check_keys([h | t], acc) do
    check_keys(t, check_keys(h, acc))
  end

  defp check_keys({:or, keys}, acc) do
    {uniq_set, dup_set} =
      keys
      |> Enum.map(&check_keys(&1, acc))
      |> Enum.reduce({MapSet.new([]), MapSet.new([])}, fn {us, ds}, {ums, dms} ->
        {
          MapSet.union(ums, MapSet.new(us)),
          MapSet.union(dms, MapSet.new(ds))
        }
      end)

    {Enum.into(uniq_set, []), Enum.into(dup_set, [])}
  end

  defp check_keys({:and, keys}, acc) do
    check_keys(keys, acc)
  end

  defp check_keys(%Vow.Ref{fun: f}, acc) do
    check_keys(f, acc)
  end

  defp check_keys({_, f}, acc) do
    check_keys(f, acc)
  end

  defp check_keys(f, {acc, dups}) do
    if f in acc do
      {acc, [f | dups]}
    else
      {[f | acc], dups}
    end
  end

  @spec update_keys([Vow.vow_ref_expr()], module | nil) :: [Vow.vow_ref_expr()]
  defp update_keys([], _mod) do
    []
  end

  defp update_keys([h | t], mod) do
    [update_key(h, mod) | update_keys(t, mod)]
  end

  @spec update_key(Vow.vow_ref_expr(), module | nil) :: Vow.vow_ref_expr()
  defp update_key({:or, keys}, mod) do
    {:or, update_keys(keys, mod)}
  end

  defp update_key({:and, keys}, mod) do
    {:and, update_keys(keys, mod)}
  end

  defp update_key(%Vow.Ref{} = ref, _mod) do
    ref
  end

  defp update_key({_, _} = mf, _mod) do
    mf
  end

  defp update_key(f, m) do
    {m, f}
  end

  @spec find_key(t | [Vow.vow_ref_expr()], atom, path) ::
          {Vow.Ref.t(), :required | :optional | nil, path} | nil
        when path: [term]
  defp find_key(vow, key, path \\ [])

  defp find_key(%__MODULE__{} = vow, key, _path) do
    case find_key(vow.required, key, [0]) do
      {ref, _, path} ->
        {ref, :required, path}

      _ ->
        case find_key(vow.optional, key, [0]) do
          {ref, _, path} -> {ref, :optional, path}
          _ -> nil
        end
    end
  end

  defp find_key([%Vow.Ref{fun: key} = ref | _], key, path) do
    {ref, nil, :lists.reverse(path)}
  end

  defp find_key([{m, key} | t], key, path) do
    find_key([Vow.Ref.new(m, key) | t], key, path)
  end

  defp find_key([{op, keys} | t], key, [ph | pt] = path) when op in [:and, :or] do
    case find_key(keys, key, [0, 1 | path]) do
      {ref, _, path} -> {ref, nil, path}
      _ -> find_key(t, key, [ph + 1 | pt])
    end
  end

  defp find_key([_ | t], key, [ph | pt]) do
    find_key(t, key, [ph + 1 | pt])
  end

  defp find_key(_, _, _) do
    nil
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    @impl Vow.RegexOperator
    def conform(_vow, _path, _via, _route, _val) do
      {:error, []}
    end

    @impl Vow.RegexOperator
    def unform(_vow, _val) do
      {:error, %Vow.UnformError{}}
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    import Vow.FunctionWrapper
    import Vow.Ref
    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(vow, path, via, route, val)
        when is_map(val) do
      context = {path, via, route}

      case conform_impl(false, vow.optional, val, context) do
        {:error, problems} ->
          {:error, problems}

        {:ok, optional} ->
          conform_impl(true, vow.required, optional, context)
      end
    end

    def conform(_vow, path, via, route, val) do
      {:error, [ConformError.new_problem(&is_map/1, path, via, route, val)]}
    end

    @impl Vow.Conformable
    def unform(vow, val) when is_map(val) do
      case unform_impl(false, vow.optional, val) do
        {:ok, unformed} -> unform_impl(true, vow.required, unformed)
        {:error, reason} -> {:error, reason}
      end
    end

    def unform(vow, val) do
      {:error, %Vow.UnformError{vow: vow, val: val}}
    end

    @impl Vow.Conformable
    def regex?(%@for{regex?: regex?}), do: regex?

    @spec unform_impl(boolean, [Vow.vow_ref_expr()] | Vow.vow_ref_expr(), map) ::
            {:ok, map} | {:error, Vow.UnformError.t()}
    defp unform_impl(required?, keys, val) when is_list(keys) do
      Enum.reduce(keys, {:ok, val}, fn
        _, {:error, reason} ->
          {:error, reason}

        k, {:ok, v} ->
          unform_impl(required?, k, v)
      end)
    end

    defp unform_impl(required?, {:or, keys} = vow, val) do
      Enum.reduce(keys, {:error, %Vow.UnformError{vow: vow, val: val}}, fn
        _, {:ok, unformed} ->
          {:ok, unformed}

        k, {:error, _} ->
          case unform_impl(required?, k, val) do
            {:ok, unformed} -> {:ok, unformed}
            {:error, _reason} -> {:error, %Vow.UnformError{vow: vow, val: val}}
          end
      end)
    end

    defp unform_impl(required?, {:and, keys}, val) do
      unform_impl(required?, keys, val)
    end

    defp unform_impl(required?, %Vow.Ref{fun: f} = ref, val) do
      case {required?, Map.has_key?(val, f)} do
        {_, true} -> @protocol.unform(ref, val)
        {true, false} -> {:error, %Vow.UnformError{vow: ref, val: val}}
        {false, false} -> {:ok, val}
      end
    end

    defp unform_impl(required?, {m, f}, val) do
      unform_impl(required?, Vow.Ref.new(m, f), val)
    end

    defp unform_impl(required?, f, val) do
      unform_impl(required?, {nil, f}, val)
    end

    @spec conform_impl(
            boolean(),
            [Vow.vow_ref_expr()] | Vow.vow_ref_expr(),
            map,
            {[term], [Vow.Ref.t()], [term]}
          ) ::
            {:ok, Vow.Conformable.conformed()} | {:error, [ConformError.Problem.t()]}
    defp conform_impl(required?, keys, val, context)
         when is_list(keys) do
      Enum.reduce(keys, {:ok, val}, fn
        _, {:error, ps} ->
          {:error, ps}

        k, {:ok, c} ->
          conform_impl(required?, k, c, context)
      end)
    end

    defp conform_impl(required?, {:or, keys}, val, context)
         when is_list(keys) do
      Enum.reduce(keys, {:error, []}, fn
        _, {:ok, c} ->
          {:ok, c}

        k, {:error, ps} ->
          case conform_impl(required?, k, val, context) do
            {:ok, c} -> {:ok, c}
            {:error, pblms} -> {:error, ps ++ pblms}
          end
      end)
    end

    defp conform_impl(required?, {:and, keys}, val, context) do
      conform_impl(required?, keys, val, context)
    end

    defp conform_impl(required?, {m, f}, val, context) do
      conform_impl(required?, sref(m, f), val, context)
    end

    # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
    defp conform_impl(required?, %Vow.Ref{fun: f} = ref, val, {path, via, route}) do
      case {required?, Map.has_key?(val, f)} do
        {_, true} ->
          case @protocol.conform(ref, path, via, [f | route], Map.get(val, f)) do
            {:ok, conformed} -> {:ok, Map.put(val, f, conformed)}
            {:error, problems} -> {:error, problems}
          end

        {true, false} ->
          {:error,
           [
             ConformError.new_problem(
               wrap(&Map.has_key?(&1, f), f: f),
               path,
               via,
               route,
               val
             )
           ]}

        {false, false} ->
          {:ok, val}
      end
    end
  end

  # coveralls-ignore-start
  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra
    import Vow.Ref

    @opts [break: :flex, separator: ","]

    @impl Inspect
    def inspect(keys, opts) do
      coll = [req: keys.required, opt: keys.optional]
      fun = fn {k, v}, os -> concat([to_string(k), "=", inspect_expr(v, os)]) end
      prefix = if keys.regex?, do: "#Keys*<", else: "#Keys<"
      container_doc(prefix, coll, ">", opts, fun, @opts)
    end

    @spec inspect_expr([Vow.vow_ref_expr()] | Vow.vow_ref_expr(), Inspect.Opts.t()) ::
            Inspect.Algebra.t()
    defp inspect_expr(expr, opts) when is_list(expr) do
      container_doc("[", expr, "]", opts, &inspect_expr/2, @opts)
    end

    defp inspect_expr({:or, keys}, opts) do
      container_doc("#or<", keys, ">", opts, &inspect_expr/2, @opts)
    end

    defp inspect_expr({:and, keys}, opts) do
      container_doc("#and<", keys, ">", opts, &inspect_expr/2, @opts)
    end

    defp inspect_expr(%Vow.Ref{} = ref, opts) do
      @protocol.inspect(ref, opts)
    end

    defp inspect_expr({m, f}, opts) do
      inspect_expr(sref(m, f), opts)
    end

    defp inspect_expr(f, opts) do
      inspect_expr(sref(f), opts)
    end
  end

  # coveralls-ignore-stop

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(_vow, _opts) do
        # traverse tree, accumulate all combinations of keys for required and optional

        # combinations -> [[{atom, generator}]] -> [%{atom => generator}]
        # [{m, f} | Ref] |> Enum.map(fn -> {f, gen(ref, opts)} end) |> Enum.into(%{})

        # tuple({fixed_map(one_of(potential_required)), fixed_map(one_of([potential_optional]))})
        # |> map(fn {req_map, opt_map} -> Map.merge(opt_map, req_map) end)
        {:error, :not_implemented}
      end
    end
  end
end
