defmodule Vow do
  @moduledoc """
  QUICK SUMMARY

  SHOW HOW TO USE (conform/2, unform/2, gen/2)

  `Vow.Conformable`
  `Vow.Generatable`

  ## Conformable Types

  The following Elixir types have `Vow.Conformable` implementations and their
  behavior will be discussed in their corresponding section below. They are
  divided into two groups: leaf vows and composite vows.

  Composite Vows:

    * `List`
    * `Tuple`
    * `Map`
    * `Struct`

  Leaf Vows:

    * `Function`
    * `MapSet`
    * `Regex`
    * `Range`
    * `Date.Range`
    * `Any`

  ### Function

  1-arity functions that return booleans are valid vows. Raises, throws, exits,
  and non-`true` returns as a result of exectuing the given vow function will
  fail to conform the given value.

    ```
    iex> Vow.conform(fn _ -> true end, nil)
    {:ok, nil}

    # function returns false, so will never succeed
    iex> Vow.valid?(fn _ -> false end, nil)
    false

    # function returns a non-boolean value, so it fails
    iex> Vow.valid?(fn _ -> "not a boolean" end, nil)
    false

    # function raises, so it fails
    iex> Vow.valid?(fn _ -> raise %ArgumentError{} end, nil)
    false

    # function throws, so it fails
    iex> Vow.valid?(fn _ -> throw :foo end, nil)
    false

    # function exits, so it fails
    iex> Vow.valid?(fn _ -> exit :bad end, nil)
    false
    ```

  ### List, Tuple, and Map

  `List`, `Tuple`, and `Map` all represent 'fixed' versions of `Vow.list_of/2`,
  and `Vow.map_of/2`. Each element in the vow list, tuple, or map is the vow
  for the conformation of the corresponding element in the value list, tuple,
  or map.

    ```
    iex> vow = [&is_integer/1, &is_float/1]
    ...> Vow.valid?(vow, [1, 2.2])
    true

    # one of the elements does not conform
    iex> vow = [&is_integer/1, &is_float/1]
    ...> Vow.valid?(vow, [:not_int, 2.2])
    false

    # value length does not match vow
    iex> vow = [&is_integer/1, &is_float/1]
    ...> Vow.valid?(vow, [1, 2.2, 42])
    false
    ```

  Note that improper lists are valid vows.

    ```
    iex> vow = [&is_integer/1 | &is_atom/1]
    ...> Vow.valid?(vow, [0 | :foo])
    true

    # the improper tail does not conform
    iex> vow = [&is_integer/1 | &is_atom/1]
    ...> Vow.valid?(vow, [0 | "not atom"])
    false

    # one of the elements does not conform
    iex> vow = [&is_integer/1 | &is_atom/1]
    ...> Vow.valid?(vow, [:not_int | :foo])
    false

    # value length does not match vow
    iex> vow = [&is_integer/1 | &is_atom/1]
    ...> Vow.valid?(vow, [0, 1 | :foo])
    false
    ```

  This works for `Tuple` and `Map` in the same way.

  ### MapSet

  A `MapSet` will behave in two different ways based on the type of value
  it is comparing itself to.

  If the value is also a `MapSet`, then the vow mapset is satified if the
  value mapset is a subset of it (i.e. if the every member in the value mapset
  is also contained in the vow mapset).

    ```
    # both :a and :c are contained within the vow
    iex> vow = MapSet.new([:a, :b, :c])
    ...> Vow.valid?(vow, MapSet.new([:a, :c]))
    true

    # :d is not contained within the vow, therefore it will fail
    iex> vow = MapSet.new([:a, :b, :c])
    ...> Vow.valid?(vow, MapSet.new([:b, :d]))
    false
    ```

  If the value is anything other than a `MapSet`, then then vow will be
  satified if the value is a member of the vow.

    ```
    iex> vow = MapSet.new([:a, :b, :c])
    ...> Vow.valid?(vow, :b)
    true

    iex> vow = MapSet.new([:a, :b, :c])
    ...> Vow.valid?(vow, :d)
    false
    ```

  ### Regex

  A `Regex` will successfully conform a value if that value is a string and
  it matches the regex successfully.

    ```
    iex> Vow.valid?(~r/^[a-zA-Z]+$/, "abc")
    true

    # value does not match the regex
    iex> Vow.valid?(~r/^[a-zA-Z]+$/, "abc123")
    false

    # value is not a string
    iex> Vow.valid?(~r/^[a-zA-Z]+$/, %{a: 1})
    false
    ```

  ### Range

  A `Range` will behave in two different ways based on the type of value
  it is comparing itself to.

  If the value is also a `Range` then the vow range is satisfied if the value
  range is bounded by the vow range.

    ```
    iex> Vow.valid?(1..10, 1..3)
    true

    iex> Vow.valid?(1..10, 5..11)
    false
    ```

  If the value is anything other than a `Range`, then the vow will be satisfied
  if the value is contained within the range.

    ```
    iex> Vow.valid?(1..10, 5)
    true

    iex> Vow.valid?(1..10, 0)
    false
    ```

  ### Date.Range

  A `Date.Range` will behave in two different ways based on the type of value
  it is comparing itself to.

  If the value is also a `Date.Range` then then vow date range is satisfied if
  the value date range is bounded by the vow date range.

    ```
    iex> vow = Date.range(~D[2010-01-01], ~D[2010-03-01])
    ...> Vow.valid?(vow, Date.range(~D[2010-01-01], ~D[2010-02-01]))
    true

    iex> vow = Date.range(~D[2010-01-01], ~D[2010-03-01])
    ...> Vow.valid?(vow, Date.range(~D[2010-02-01], ~D[2010-03-02]))
    false
    ```

  If the value is anything other than a `Date.Range`, then the vow will be
  satisfied if the value is a member of the date range.

    ```
    iex> vow = Date.range(~D[2010-01-01], ~D[2010-03-01])
    ...> Vow.valid?(vow, ~D[2010-02-15])
    true

    iex> vow = Date.range(~D[2010-01-01], ~D[2010-03-01])
    ...> Vow.valid?(vow, ~D[2010-04-01])
    false
    ```

  ### Structs

  All structs that do not implement `Vow.Conformable` conformed similar to
  maps after first validating that the vow struct and value struct share the
  same module under the `:__struct__` key.

    ```
    iex> vow = %ArgumentError{message: "foo"}
    ...> Vow.conform(vow, %ArgumentError{message: "foo"})
    {:ok, %ArgumentError{message: "foo"}}
    ```

  ### Any

  Any type not mentioned below are treated atomically for the purposes of
  conforming values.

    ```
    iex> Vow.conform(:foo, :foo)
    {:ok, :foo}

    iex> Vow.valid?(:foo, :bar)
    false
    ```

  ## Conformed / Destructured Values

  A conformed value (sometimes referred to a potentially destructured value),
  is the result of calling `Vow.conform/2` on a value.

  The vows that do destructure the values given to them are:

    * `Vow.Alt`
    * `Vow.Cat`
    * `Vow.OneOf`

  But it's worth noting that any composite vow (i.e. a vow that contains vows)
  may result in a destructured value as they may contain a vow that does
  destructure it's value.

  ## Regex Operators

  The following vows are regex operators:

    * `Vow.cat/1` - a concatenation of vows
    * `Vow.alt/1` - a choice of one among a set of vows
    * `Vow.zom/1` - zero or more occurences of a vow
    * `Vow.oom/1` - one or more
    * `Vow.maybe/1` - one or none
    * `Vow.amp/1` - takes a vow and further constrains it with one or more vows

  These nest arbitrarily to form complex expressions.

  Nested regex vows compose to describe a single sequence / enumerable. Shown
  below is an example of the different nesting behaviors of `Vow.also/1` and
  `Vow.amp/1`.

    ```
    # using `Vow.also/1`
    iex> import Vow
    ...> import Vow.FunctionWrapper
    ...> vow = oom(alt(
    ...>   n: &is_number/1,
    ...>   s: also(
    ...>     bs: oom(&is_bitstring/1),
    ...>     ne: wrap(&Enum.all?(&1, fn s -> String.length(s) > 0 end))
    ...>   )
    ...> ))
    ...> Vow.valid?(vow, [1, ["x", "a"], 2, ["y"], ["z"]])
    true

    # using `Vow.amp/1` (i.e. the regex operator)
    iex> import Vow
    ...> import Vow.FunctionWrapper
    ...> regex_vow = oom(alt(
    ...>   n: &is_number/1,
    ...>   s: amp(
    ...>     bs: oom(&is_bitstring/1),
    ...>     ne: wrap(&Enum.all?(&1, fn s -> String.length(s) > 0 end))
    ...>   )
    ...> ))
    ...> Vow.valid?(regex_vow, [1, "x", "a", 2, "y", "z"])
    true
    ```

  ## Utilities

  These modules and their associated macros are meant to aid in the
  construction of your own vows. See their respecitive modules for more
  details.

  `Vow.FunctionWrapper` helps with better annoymous function inspecting. It
  conforms the same way a normal function does, but exposes the macro
  `Vow.FunctionWrapper.wrap/2` to help display the function for errors.

  `Vow.Ref` allows for a reference to a 0-arity function that returns a vow.
  Since this resolves whenever a conform occurs, this enables recursive vow
  definitions and greater reusability of vows.

  `Vow.Pat` wraps the AST of a pattern and will use Elixir pattern matching
  to validate at conformation occurs. This also supports `Expat` patterns.

  ## Notes

  See [clojure.spec](https://clojure.org/about/spec) docs for more details
  and rationale from the primary influence of this library.
  """

  import Kernel, except: [get_in: 2, update_in: 3, put_in: 3, get_and_update_in: 3, pop_in: 2]
  alias Vow.{Conformable, ConformError}

  @type t :: Conformable.t()

  @doc """
  Given a `vow` and a `value`, returns an `{:error, conform_error}` if
  `value` does not match the `vow`, otherwise returns `{:ok, conformed}`
  where `conformed` is a possibly destructured value.

  ## Examples

    ```
    iex> Vow.conform(&is_integer/1, 42)
    {:ok, 42}
    iex> Vow.conform(Vow.list_of(Vow.one_of([i: &is_integer/1, a: &is_atom/1, s: &is_bitstring/1])), [0, :b, "c"])
    {:ok, [%{i: 0}, %{a: :b}, %{s: "c"}]}
    iex> Vow.conform(&is_atom/1, 42)
    {:error, %Vow.ConformError{problems: [%Vow.ConformError.Problem{path: [], pred: &is_atom/1, reason: nil, route: [], val: 42, via: []}], val: 42, vow: &is_atom/1}}
    ```
  """
  @spec conform(t, value :: term) :: {:ok, Conformable.conformed()} | {:error, ConformError.t()}
  def conform(vow, value) do
    case Conformable.conform(vow, [], [], [], value) do
      {:ok, conformed} ->
        {:ok, conformed}

      {:error, problems} ->
        {:error, ConformError.new(problems, vow, value)}
    end
  end

  @doc """
  Given a `vow` and a `value`, raises a `Vow.ConformError.t` if `value`
  does not match the `vow`, otherwise returns a (possibly destructured)
  value.

  See `Vow.conform/2` for more details.
  """
  @spec conform!(t, value :: term) :: Conformable.conformed() | no_return
  def conform!(vow, value) do
    case conform(vow, value) do
      {:ok, conformed} -> conformed
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Returns true if the `value` conforms to the `vow`.
  """
  @spec valid?(t, value :: term) :: boolean
  def valid?(vow, value) do
    case conform(vow, value) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Returns true if the `value` fails to conform to the `vow`.
  """
  @spec invalid?(t, value :: term) :: boolean
  def invalid?(vow, value) do
    not valid?(vow, value)
  end

  defdelegate unform(vow, value), to: Vow.Conformable

  defdelegate get_in(data, keys), to: Acs
  defdelegate get_and_update_in(data, keys, fun), to: Acs
  defdelegate update_in(data, keys, fun), to: Acs
  defdelegate put_in(data, keys, fun), to: Acs
  defdelegate pop_in(data, keys), to: Acs

  @typedoc """
  A generator override for a vow is the combination for a path
  (i.e. the 'navigable' path to the sub-vow to be replaced) and
  the generator function (i.e. 0-arity function that returns a
  generator).

  These are extremely useful for 'optimizing' the generation of
  a vow. A common use-case for this would be with `Vow.one_of/1`.

  `Vow` allows one to specify the allowed forms of data, whereas
  a library like `StreamData` allows for more semantics around
  what is 'likely' to be generated (i.e. `StreamData.one_of/1`
  vs `StreamData.frequency/1`).

  See also `Vow.with_gen/2`.
  """
  @type override :: {path :: [term], Vow.Generatable.gen_fun()}

  @type gen_opt :: Vow.Generatable.gen_opt() | {:overrides, [override]}

  @doc """
  Returns a generator for the specified `vow`.
  """
  @spec gen(t, keyword) :: {:ok, Vow.Generatable.generator()} | {:error, reason :: term}
  def gen(vow, opts \\ []) do
    {overrides, opts} = Keyword.pop(opts, :overrides, [])

    overridden_vow =
      Enum.reduce(overrides, vow, fn {path, gen_fun}, acc ->
        put_in(acc, path, gen_fun.())
      end)

    Vow.Generatable.gen(overridden_vow, opts)
  end

  defdelegate with_gen(vow, gen_fun), to: Vow.WithGen, as: :new

  @doc """
  Given a `vow` and a destructured `value`, returns the original value or
  raises a `Vow.UnformError.t`.

  See `Vow.unform/2` for more details.
  """
  @spec unform!(t, Conformable.conformed()) :: value :: term | no_return
  def unform!(vow, value) do
    case unform(vow, value) do
      {:ok, unformed} -> unformed
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Converts the specified `enumerable` into a `MapSet.t`.
  """
  @spec set(Enum.t()) :: MapSet.t()
  def set(enumerable), do: MapSet.new(enumerable)

  @doc """
  Returns true if given a term.
  """
  @spec term?(term) :: true
  def term?(_term), do: true

  @doc """
  Returns true if given anything.
  """
  @spec any?(term) :: true
  def any?(term), do: term?(term)

  @doc """
  Returns a vow that successfully conforms a value if all given `named_vows`
  are successfully conformed. Successive, and possible destructured,
  conformed values propagate through the rest of the vows, in order.

  ## Examples

    ```
    iex> vow = Vow.also(list: &is_list/1, len: &(length(&1) > 1))
    ...> Vow.conform(vow, [1, 2, 3])
    {:ok, [1, 2, 3]}
    ```
  """
  @spec also([{atom, t}]) :: t
  def also(named_vows) do
    Vow.Also.new(named_vows)
  end

  @doc """
  Returns a vow that successfully conforms a value if any of the given
  `named_vows` successfully conform the value.

  The returned value will always be a map containing the key of the first
  vow that successfully conformed, with the value being the conformed value.

  ## Examples

    ```
    iex> vow = Vow.one_of(int: &is_integer/1, float: &is_float/1, any: &Vow.any?/1)
    ...> Vow.conform(vow, 42)
    {:ok, %{int: 42}}

    iex> vow = Vow.one_of(int: &is_integer/1, float: &is_float/1, any: &Vow.any?/1)
    ...> Vow.conform(vow, 10.2)
    {:ok, %{float: 10.2}}

    iex> vow = Vow.one_of(int: &is_integer/1, float: &is_float/1, any: &Vow.any?/1)
    ...> Vow.conform(vow, :foo)
    {:ok, %{any: :foo}}
    ```
  """
  @spec one_of([{atom, t}, ...]) :: t | no_return
  def one_of(named_vows)
      when is_list(named_vows) and length(named_vows) > 0 do
    Vow.OneOf.new(named_vows)
  end

  @doc """
  Returns a vow that accepts `nil` and values satisfying the given `vow`.

  ## Examples

    ```
    iex> vow = Vow.nilable(&is_integer/1)
    ...> Vow.conform(vow, nil)
    {:ok, nil}

    iex> vow = Vow.nilable(&is_integer/1)
    ...> Vow.conform(vow, 42)
    {:ok, 42}

    iex> vow = Vow.nilable(&is_integer/1)
    ...> Vow.valid?(vow, "not an integer or nil!")
    false
    ```
  """
  @spec nilable(t) :: t
  def nilable(vow) do
    Vow.Nilable.new(vow)
  end

  @typedoc """
  Options for list, keyword, and map vow construction.

    * `:length` - the length of the list specified as an integer or range
    (will override `min_length` and/or `:max_length` if either are present)
    * `:min_length` - the minimum acceptable length of the list (defaults to `0`)
    * `:max_length` - the maximum acceptable length of the list
    * `:distinct?` - specifies whether the elements of the list should be unique
    (defaults to `false`)
  """
  @type list_opt ::
          {:length, Range.t() | non_neg_integer}
          | {:min_length, non_neg_integer}
          | {:max_length, non_neg_integer}
          | {:distinct?, boolean}

  @doc """
  Returns a vow that accepts a list of elements that all conform to the given
  `vow` in addition to whatever constraints have been specified in the `opts`.

  See `list_opt` type for more details.

  ## Examples

    ```
    iex> vow = Vow.list_of(Vow.one_of(i: &is_integer/1, s: &is_bitstring/1))
    ...> Vow.conform(vow, [1, 2, 3, "foo", 5, "bar"])
    {:ok, [%{i: 1}, %{i: 2}, %{i: 3}, %{s: "foo"}, %{i: 5}, %{s: "bar"}]}
    ```
  """
  @spec list_of(t, [list_opt]) :: t
  def list_of(vow, opts \\ []) do
    distinct? = Keyword.get(opts, :distinct?, false)
    {min, max} = get_range(opts)
    Vow.List.new(vow, min, max, distinct?)
  end

  @doc false
  @spec get_range([list_opt]) :: {non_neg_integer, non_neg_integer | nil}
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
  Equivalent to `Vow.list_of({&is_atom/1, vow}, opts)`.

  See `Vow.list_of/2` for more details.
  """
  @spec keyword_of(t, [list_opt]) :: t
  def keyword_of(vow, opts \\ []) do
    list_of({&is_atom/1, vow}, opts)
  end

  @typedoc """
  Options for map vow construction.

    * `:conform_keys?` - `true` will result in the map keys being overridden by
    the result of their conformation, while the default, `false`, will result
    in no change to the map keys.

  This distinction between conforming or not conforming keys is important
  because of the potential for vows to destructure the values they conform,
  which may not be desired for map keys.

  See `list_opt` for more details.
  """
  @type map_opt ::
          list_opt
          | {:conform_keys?, boolean}

  @doc """
  Returns a vow that successfully conforms a value if it is a map whose keys
  all conform to the `key_vow`, and whose values all conform to the
  `value_vow`.

  ## Examples

    ```
    iex> vow = Vow.map_of(&is_atom/1, &is_integer/1)
    ...> Vow.conform(vow, %{a: 1, b: 2, c: 3})
    {:ok, %{a: 1, b: 2, c: 3}}

    iex> vow = Vow.map_of(&is_atom/1, &is_integer/1)
    ...> Vow.valid?(vow, %{a: 1, b: :not_integer, c: 3})
    false
    ```
  """
  @spec map_of(key_vow :: t, value_vow :: t, [map_opt]) :: t
  def map_of(key_vow, value_vow, opts \\ []) do
    conform_keys? = Keyword.get(opts, :conform_keys?, false)
    {min, max} = get_range(opts)
    Vow.Map.new(key_vow, value_vow, min, max, conform_keys?)
  end

  @typedoc """
  Any `Vow.t` that represents a `Map` or `Keyword`.
  """
  @type merged ::
          Vow.Merge.t()
          | Vow.Map.t()
          | Vow.Keys.t()
          | map

  @doc """
  Takes map-validating vows and returns a vow that returns a conformed
  map satifying all of the vows.

  ## Examples

    ```
    iex> vow = Vow.merge(
    ...>   req: %{a: -100..0, b: 1..100},
    ...>   opt: Vow.map_of(&is_atom/1, &is_integer/1)
    ...> )
    ...> Vow.conform(vow, %{a: -42, b: 35, c: 0, d: 10000})
    {:ok, %{a: -42, b: 35, c: 0, d: 10000}}
    ```

  ## Notes

  Unlike `Vow.also/1`, merge can generate maps satifying the union of
  the `named_vows`.
  """
  @spec merge([{atom, merged}]) :: t
  def merge(named_vows) do
    Vow.Merge.new(named_vows)
  end

  @typedoc """
  Either a `Vow.Ref.t` or the module, function pair used to construct
  the `Vow.Ref.t`. Also supports just the function named if the
  `:default_module` is specified (see `key_opt` for more details).
  """
  @type vow_ref :: atom | {module, atom} | Vow.Ref.t()

  @typedoc """
  This expression represents a set of valid `Vow.Ref` combinations and
  supports nested `{:and, [...]}` and `{:or, []}` notation.
  """
  @type vow_ref_expr ::
          vow_ref
          | {:and | :or, [vow_ref_expr, ...]}

  @typedoc """
  Options for keys vow construction:

    * `:required` - the expression describing the required keys (defaults to `[]`)
    * `:optional` - the expression describing the optional keys (defulats to `[]`)
    * `:default_module` - the default module to use when a vow_ref is
    unspecified (defaults to `nil`)
    * `:regex?` -
  """
  @type key_opt ::
          {:required, [vow_ref_expr]}
          | {:optional, [vow_ref_expr]}
          | {:default_module, module | nil}
          | {:regex?, boolean}

  @doc """
  Returns a map validating vow that takes a set of vow reference
  expressions in the `:required` and `:optional` `opts`.

  A vow reference is a named vow (see `Vow.Ref` for more details),
  and the expression part supports nested 'and' and 'or' operators
  (see `vow_ref_expr` type).

  The reference function name is implied to be the key name and the
  value corresponding to that key must conform with the vow referenced.

  ## Examples

    ```
    iex> defmodule Foo do
    ...>   def x, do: &is_integer/1
    ...>   def y, do: &is_float/1
    ...> end
    ...> vow = Vow.keys(required: [{Foo, :x}, {Foo, :y}])
    ...> Vow.conform(vow, %{x: 42, y: 42.0})
    {:ok, %{x: 42, y: 42.0}}
    ```

  ## Notes

  There is no support for inline vow specification, by design.

  This is by default not a regex operator, but if the `:regex?` flag in the
  `opts` is set to `true`, then it behaves as a regex operator.
  """
  @spec keys([key_opt]) :: t | no_return
  def keys(opts) do
    required = Keyword.get(opts, :required, [])
    optional = Keyword.get(opts, :optional, [])
    default_module = Keyword.get(opts, :default_module, nil)
    regex? = Keyword.get(opts, :regex?, false)
    Vow.Keys.new(required, optional, default_module, regex?)
  end

  @doc """
  This macro wraps `Vow.keys/1` with a default `:default_module`
  value of the caller's module (via `__CALLER__.module`).

  If having this default value is not useful, then using `Vow.keys/1`
  is preferred.
  """
  @spec mkeys([key_opt]) :: Macro.t()
  defmacro mkeys(opts) do
    opts = Keyword.put(opts, :default_module, __CALLER__.module)

    quote do
      Vow.keys(unquote(opts))
    end
  end

  @doc """
  Returns `true` if the given `vow` is a regex operator,
  otherwise returns `false`.
  """
  @spec regex?(t) :: boolean
  def regex?(vow) do
    Conformable.regex?(vow)
  end

  @doc """
  Returns a vow that consumes values and subjects them to the conjunction
  of the `named_vows`, and any conforming they might perform.

  ## Notes

  This is a regex operator that behaves similarly to `Vow.also/1`.
  """
  @spec amp([{atom, t}]) :: t
  def amp(named_vows) do
    Vow.Amp.new(named_vows)
  end

  @doc """
  Returns a vow that matches zero or one value matching the specified `vow`.
  Produces either an empty list, or a list of a single element.

  ## Notes

  This is a regex operator.
  """
  @spec maybe(t) :: t
  def maybe(vow) do
    Vow.Maybe.new(vow)
  end

  @doc """
  Returns a vow that matches one or more values matching the specified `vow`.
  Produces a list of matches.

  ## Notes

  This is a regex operator.
  """
  @spec one_or_more(t) :: t
  def one_or_more(vow) do
    Vow.OneOrMore.new(vow)
  end

  @doc """
  Shorthand for `Vow.one_or_more/1`.
  """
  @spec oom(t) :: t
  def oom(vow), do: one_or_more(vow)

  @doc """
  Returns a vow that matches zero or more values matching the specified `vow`.
  Produces a list of matches.

  ## Notes

  This is a regex operator.
  """
  @spec zero_or_more(t) :: t
  def zero_or_more(vow) do
    Vow.ZeroOrMore.new(vow)
  end

  @doc """
  Shorthand for `Vow.zero_or_more/1`.
  """
  @spec zom(t) :: t
  def zom(vow), do: zero_or_more(vow)

  @doc """
  Returns a vow that returns a map containing the key of the first matching
  vow and the corresponding conformed value.

  ## Notes

  This is a regex operator that behaves similarly to `Vow.one_of/1`.
  """
  @spec alt([{atom, t}, ...]) :: t | no_return
  def alt(named_vows)
      when is_list(named_vows) and length(named_vows) > 0 do
    Vow.Alt.new(named_vows)
  end

  @doc """
  Returns a vow that matches all values in a list, returning a map containing
  the keys of each name in `named_vows` and the corresponding conformed value.

  ## Notes

  This is a regex operator.
  """
  @spec cat([{atom, t}, ...]) :: t | no_return
  def cat(named_vows)
      when is_list(named_vows) and length(named_vows) > 0 do
    Vow.Cat.new(named_vows)
  end

  defdelegate conform_function(vow, function, args \\ []), to: Vow.Function, as: :conform
end
