defmodule Vow.Keys do
  @moduledoc false
  @behaviour Access

  defstruct required: [],
            optional: []

  @type t :: %__MODULE__{
          required: [Vow.vow_ref_expr()],
          optional: [Vow.vow_ref_expr()]
        }

  @spec new([Vow.vow_ref_expr()], [Vow.vow_ref_expr()], module | nil) :: t | no_return
  def new(required, optional, default_module \\ nil) do
    required = update_keys(required, default_module)
    optional = update_keys(optional, default_module)

    case check_keys(required ++ optional) do
      {_, [_ | _] = dups} ->
        raise %Vow.DuplicateKeyError{duplicates: dups}

      _ ->
        %__MODULE__{
          required: required,
          optional: optional
        }
    end
  end

  @impl Access
  def fetch(%__MODULE__{} = _vow, _key) do
    :error
  end

  @impl Access
  def get_and_update(%__MODULE__{} = vow, _key, _fun) do
    {nil, vow}
  end

  @impl Access
  def pop(%__MODULE__{} = vow, _key) do
    {nil, vow}
  end

  # NOTE: 'genericize' traversal of the expr tree/path?

  @spec check_keys([Vow.vow_ref_expr()] | Vow.vow_ref_expr(), {[atom], [atom]}) ::
          {[atom], [atom]}
  defp check_keys(keys, acc \\ {[], []})
  defp check_keys([], acc), do: acc

  defp check_keys([h | t], acc) do
    check_keys(h, acc)
    |> (&check_keys(t, &1)).()
  end

  defp check_keys({:or, keys}, acc) do
    {uniq_set, dup_set} =
      Enum.map(keys, &check_keys(&1, acc))
      |> Enum.reduce({MapSet.new([]), MapSet.new([])}, fn {us, ds}, {ums, dms} ->
        {
          MapSet.union(ums, MapSet.new(us)),
          MapSet.union(dms, MapSet.new(ds))
        }
      end)

    {Enum.into(uniq_set, []), Enum.into(dup_set, [])}
  end

  defp check_keys({:and, keys}, acc), do: check_keys(keys, acc)
  defp check_keys(%Vow.Ref{fun: f}, acc), do: check_keys(f, acc)
  defp check_keys({_, f}, acc), do: check_keys(f, acc)

  defp check_keys(f, {acc, dups}) do
    if f in acc do
      {acc, [f | dups]}
    else
      {[f | acc], dups}
    end
  end

  @spec update_keys([Vow.vow_ref_expr()], module | nil) :: [Vow.vow_ref_expr()]
  defp update_keys([], _mod), do: []

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

  defp update_key(%Vow.Ref{} = ref, _mod), do: ref
  defp update_key({_, _} = mf, _mod), do: mf
  defp update_key(f, m), do: {m, f}

  defimpl Vow.Conformable do
    @moduledoc false

    import Vow.FunctionWrapper
    import Vow.Ref
    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(vow, vow_path, via, value_path, value)
        when is_map(value) do
      context = {vow_path, via, value_path}

      case conform_impl(false, vow.optional, value, context) do
        {:error, problems} ->
          {:error, problems}

        {:ok, optional} ->
          conform_impl(true, vow.required, optional, context)
      end
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, vow_path, via, value_path, value)]}
    end

    @impl Vow.Conformable
    def unform(vow, value) when is_map(value) do
      case unform_impl(false, vow.optional, value) do
        {:ok, unformed} -> unform_impl(true, vow.required, unformed)
        {:error, reason} -> {:error, reason}
      end
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end

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
      Enum.reduce(keys, {:error, %Vow.UnformError{vow: vow, value: val}}, fn
        _, {:ok, unformed} ->
          {:ok, unformed}

        k, {:error, _} ->
          case unform_impl(required?, k, val) do
            {:ok, unformed} -> {:ok, unformed}
            {:error, _reason} -> {:error, %Vow.UnformError{vow: vow, value: val}}
          end
      end)
    end

    defp unform_impl(required?, {:and, keys}, val) do
      unform_impl(required?, keys, val)
    end

    defp unform_impl(required?, %Vow.Ref{fun: f} = ref, val) do
      case {required?, Map.has_key?(val, f)} do
        {_, true} -> @protocol.unform(ref, val)
        {true, false} -> {:error, %Vow.UnformError{vow: ref, value: val}}
        {false, false} -> {:ok, val}
      end
    end

    defp unform_impl(required?, {m, f}, val) do
      unform_impl(required?, Vow.Ref.new(m, f), val)
    end

    defp unform_impl(required?, f, val), do: unform_impl(required?, {nil, f}, val)

    @spec conform_impl(
            boolean(),
            [Vow.vow_ref_expr()] | Vow.vow_ref_expr(),
            map,
            {[term], [Vow.Ref.t()], [term]}
          ) ::
            {:ok, Vow.Conformable.conformed()} | {:error, [ConformError.Problem.t()]}
    defp conform_impl(required?, keys, value, context)
         when is_list(keys) do
      Enum.reduce(keys, {:ok, value}, fn
        _, {:error, ps} ->
          {:error, ps}

        k, {:ok, c} ->
          conform_impl(required?, k, c, context)
      end)
    end

    defp conform_impl(required?, {:or, keys}, value, context)
         when is_list(keys) do
      Enum.reduce(keys, {:error, []}, fn
        _, {:ok, c} ->
          {:ok, c}

        k, {:error, ps} ->
          case conform_impl(required?, k, value, context) do
            {:ok, c} -> {:ok, c}
            {:error, pblms} -> {:error, ps ++ pblms}
          end
      end)
    end

    defp conform_impl(required?, {:and, keys}, value, context) do
      conform_impl(required?, keys, value, context)
    end

    defp conform_impl(required?, {m, f}, value, context) do
      conform_impl(required?, sref(m, f), value, context)
    end

    defp conform_impl(required?, %Vow.Ref{fun: f} = ref, value, {vow_path, via, value_path}) do
      case {required?, Map.has_key?(value, f)} do
        {_, true} ->
          case @protocol.conform(ref, vow_path, via, value_path ++ [f], Map.get(value, f)) do
            {:ok, conformed} -> {:ok, Map.put(value, f, conformed)}
            {:error, problems} -> {:error, problems}
          end

        {true, false} ->
          {:error,
           [
             ConformError.new_problem(
               wrap(&Map.has_key?(&1, f), f: f),
               vow_path,
               via,
               value_path,
               value
             )
           ]}

        {false, false} ->
          {:ok, value}
      end
    end
  end

  # coveralls-ignore-start
  defimpl Inspect do
    @moduledoc false
    import Inspect.Algebra
    import Vow.Ref

    @opts [break: :flex, separator: ","]

    def inspect(keys, opts) do
      coll = [req: keys.required, opt: keys.optional]
      fun = fn {k, v}, os -> concat([to_string(k), "=", inspect_expr(v, os)]) end
      container_doc("#Keys<", coll, ">", opts, fun, @opts)
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

    defp inspect_expr(%Vow.Ref{} = ref, opts), do: @protocol.inspect(ref, opts)
    defp inspect_expr({m, f}, opts), do: inspect_expr(sref(m, f), opts)
    defp inspect_expr(f, opts), do: inspect_expr(sref(f), opts)
  end

  # coveralls-ignore-stop

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(_vow, _opts) do
        {:error, :not_implemented}
      end
    end
  end
end
