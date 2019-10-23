defmodule ExSpec do
  @moduledoc """
  """

  alias ExSpec.{Conformable, ConformError}

  @typedoc """
  """
  @type t :: Conformable.t()

  @doc """
  """
  @spec conform(t, value :: term) :: {:ok, Conformable.conformed()} | {:error, ConformError.t()}
  def conform(spec, value) do
    case Conformable.conform(spec, [], [], [], value) do
      {:ok, conformed} ->
        {:ok, conformed}

      {:error, problems} ->
        {:error, ConformError.new(problems, spec, value)}
    end
  end

  @doc """
  """
  @spec conform!(t, value :: term) :: Conformable.conformed() | no_return
  def conform!(spec, value) do
    case conform(spec, value) do
      {:ok, conformed} -> conformed
      {:error, reason} -> raise reason
    end
  end

  @doc """
  """
  @spec valid?(t, value :: term) :: boolean
  def valid?(spec, value) do
    case conform(spec, value) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  """
  @spec invalid?(t, value :: term) :: boolean
  def invalid?(spec, value) do
    not valid?(spec, value)
  end

  @doc """
  """
  @spec explain(t, value :: term) :: ConformError.t() | nil
  def explain(spec, value) do
    case conform(spec, value) do
      {:ok, _} -> nil
      {:error, reason} -> reason
    end
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      import ExSpec
      use ExSpec.Func
      use ExSpec.Ref
    end
  end

  @doc """
  """
  @spec set(Enum.t()) :: MapSet.t()
  def set(enumerable), do: MapSet.new(enumerable)

  @doc """
  """
  @spec term?(term) :: boolean
  def term?(_term), do: true

  @doc """
  """
  @spec any?(term) :: boolean
  def any?(term), do: term?(term)

  @doc """
  """
  @spec also([t]) :: t
  def also(specs) do
    ExSpec.Also.new(specs)
  end

  @doc """
  """
  @spec also(t, t) :: t
  def also(spec1, spec2) do
    also([spec1, spec2])
  end

  @doc """
  """
  @spec one_of([{atom, t}, ...]) :: t | no_return
  def one_of(named_specs)
      when is_list(named_specs) and length(named_specs) > 0 do
    ExSpec.OneOf.new(named_specs)
  end

  @doc """
  """
  @spec nilable(t) :: t
  def nilable(spec) do
    ExSpec.Nilable.new(spec)
  end

  @typedoc """
  """
  @type list_opt ::
          {:length, Range.t() | non_neg_integer}
          | {:min_length, non_neg_integer}
          | {:max_length, non_neg_integer}
          | {:distinct?, boolean}

  @typedoc """
  """
  @type list_opts :: [list_opt]

  @doc """
  """
  @spec list_of(t, list_opts) :: t
  def list_of(spec, opts \\ []) do
    distinct? = Keyword.get(opts, :distinct?, false)
    {min, max} = get_range(opts)
    ExSpec.List.new(spec, min, max, distinct?)
  end

  @doc false
  @spec get_range(list_opts) :: {non_neg_integer, non_neg_integer | nil}
  defp get_range(opts) do
    with {:length, nil} <- {:length, Keyword.get(opts, :length)},
         {:min, min} <- {:min, Keyword.get(opts, :min_length, 0)},
         {:max, max} <- {:max, Keyword.get(opts, :max_length)} do
      {min, max}
    else
      {:length, min..max} -> {min, max}
      {:length, len} -> {len, len}
    end
  end

  @doc """
  """
  @spec keyword_of(t, list_opts) :: t
  def keyword_of(spec, opts \\ []) do
    list_of({&is_atom/1, spec}, opts)
  end

  @typedoc """
  """
  @type map_opt ::
          list_opt
          | {:conform_keys?, boolean}

  @typedoc """
  """
  @type map_opts :: [map_opt]

  @doc """
  """
  @spec map_of(key_spec :: t, value_spec :: t, map_opts) :: t
  def map_of(key_spec, value_spec, opts \\ []) do
    distinct? = Keyword.get(opts, :distinct?, false)
    conform_keys? = Keyword.get(opts, :conform_keys?, false)
    {min, max} = get_range(opts)
    ExSpec.Map.new(key_spec, value_spec, min, max, distinct?, conform_keys?)
  end

  @typedoc """
  """
  @type merged ::
          ExSpec.Merge.t()
          | ExSpec.Map.t()
          | ExSpec.Keys.t()
          | map
          | ExSpec.Alt.t()
          | ExSpec.OneOf.t()
          | ExSpec.Cat.t()

  @doc """
  """
  @spec merge([merged], (key, value, value -> value) | nil) :: t when key: term, value: term
  def merge(specs, merge_fun \\ nil) do
    ExSpec.Merge.new(specs, merge_fun)
  end

  @typedoc """
  """
  @type spec_ref :: atom | {module, atom} | ExSpec.Ref.t()

  @typedoc """
  """
  @type spec_ref_expr ::
          spec_ref
          | {:and | :or, [spec_ref_expr, ...]}

  @typedoc """
  """
  @type key_opt ::
          {:required, [spec_ref_expr]}
          | {:optional, [spec_ref_expr]}
          | {:into, [] | %{}}

  @typedoc """
  """
  @type key_opts :: [key_opt]

  @doc """
  """
  @spec keys(key_opts) :: t | no_return
  def keys(opts) do
    ExSpec.Keys.new(opts)
  end

  @doc """
  """
  @spec regex?(t) :: boolean
  def regex?(spec) do
    case ExSpec.RegexOperator.impl_for(spec) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  """
  @spec amp([t]) :: t
  def amp(specs) do
    ExSpec.Amp.new(specs)
  end

  @doc """
  """
  @spec amp(t, t) :: t
  def amp(spec1, spec2) do
    amp([spec1, spec2])
  end

  @doc """
  """
  @spec maybe(t) :: t
  def maybe(spec) do
    ExSpec.Maybe.new(spec)
  end

  @doc """
  """
  @spec one_or_more(t) :: t
  def one_or_more(spec) do
    ExSpec.OneOrMore.new(spec)
  end

  @doc """
  """
  @spec oom(t) :: t
  def oom(spec), do: one_or_more(spec)

  @doc """
  """
  @spec zero_or_more(t) :: t
  def zero_or_more(spec) do
    ExSpec.ZeroOrMore.new(spec)
  end

  @doc """
  """
  @spec zom(t) :: t
  def zom(spec), do: zero_or_more(spec)

  @doc """
  """
  @spec alt([{atom, t}, ...]) :: t | no_return
  def alt(named_specs)
      when is_list(named_specs) and length(named_specs) > 0 do
    ExSpec.Alt.new(named_specs)
  end

  @doc """
  """
  @spec cat([{atom, t}, ...]) :: t | no_return
  def cat(named_specs)
      when is_list(named_specs) and length(named_specs) > 0 do
    ExSpec.Cat.new(named_specs)
  end

  @typedoc """
  """
  @type fspec_opt ::
          {:args, [t]}
          | {:ret, t}
          | {:fun, t}

  @typedoc """
  """
  @type fspec_opts :: [fspec_opt]

  @doc """
  """
  @spec fspec(fspec_opts) :: t
  def fspec(opts) do
    args = Keyword.get(opts, :args)
    ret = Keyword.get(opts, :ret)
    fun = Keyword.get(opts, :fun)
    ExSpec.Function.new(args, ret, fun)
  end

  defdelegate conform_function(spec, function, args \\ []), to: ExSpec.Function, as: :conform
end
