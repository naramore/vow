defmodule Acs.Improper do
  @moduledoc """
  A set of utilities for interacting with improper lists.
  """

  @doc """
  Converts a proper list into an improper list, popping of the tail of the
  list and using it as the improper tail of the new improper list.

  The given list must have at least 2 elements.
  """
  @spec to_improper(list) :: nonempty_improper_list(term, term) | nil
  def to_improper(list) when length(list) >= 2, do: to_improper_impl(list, [])
  def to_improper(_list), do: nil

  @spec to_improper_impl(list, list) :: nonempty_improper_list(term, term) | nil
  defp to_improper_impl(list, acc)
  defp to_improper_impl([t | []], acc) when not is_list(t), do: :lists.reverse(acc, t)
  defp to_improper_impl([h | t], acc), do: to_improper_impl(t, [h | acc])
  defp to_improper_impl(_, _), do: nil

  @doc """
  Converts an improper list to a list, appending the improper tail onto
  the end of the new list.

  Given an proper list, this should return the same list.
  """
  @spec to_proper(nonempty_maybe_improper_list()) :: [any]
  def to_proper([]), do: []
  def to_proper([h | t]) when is_list(t), do: [h | to_proper(t)]
  def to_proper([h | t]), do: [h | [t]]

  @doc """
  Gets the specified `index` in the improper `list`. The index of the
  improper tail is one greater than the index of the last element of
  in the proper head of the list.

  ## Examples

    ```
    # last element of the proper portion of the list
    iex> Acs.Improper.improper_get([:a, :b | :c], 1)
    :b

    # improper tail is 1 greater (i.e. 2)
    iex> Acs.Improper.improper_get([:a, :b | :c], 2)
    :c
    ```
  """
  @spec improper_get(nonempty_improper_list(term, term) | term, integer) :: term | nil
  def improper_get(list, index)
  def improper_get([h | _], 0), do: h
  def improper_get([_ | t], 1) when not is_list(t), do: t

  def improper_get([_ | t], index) when index > 0 and is_list(t),
    do: improper_get(t, index - 1)

  def improper_get(list, index) when index < 0 do
    length = improper_length(list)

    if length + index >= 0 do
      improper_get(list, length + index)
    else
      nil
    end
  end

  def improper_get(_, _), do: nil

  @doc """
  Returns the length of the specified improper `list`.

  The calculated length should be the length of the proper head + 1
  (for the improper tail).
  """
  @spec improper_length(nonempty_improper_list(term, term), non_neg_integer) :: non_neg_integer
  def improper_length(list, len \\ 0)

  def improper_length([_ | t], len) when is_list(t),
    do: improper_length(t, len + 1)

  def improper_length(_, len), do: len + 2

  @doc """
  Returns true if the given `term` is a proper list, and false otherwise.
  """
  @spec proper_list?(term) :: boolean
  def proper_list?(term)
  def proper_list?([]), do: true
  def proper_list?([_ | t]) when is_list(t), do: proper_list?(t)
  def proper_list?(_), do: false
end

defmodule Acs do
  @moduledoc """
  `Acs` is shorthand for `Access` and overrides some of the default behaviour
  of `get_in/2`, `update_in/3`, `put_in/3`, `get_and_update_in/3`, and
  `pop_in/2`.

  The main behavioural changes are the following:

  * empty paths are supported (as opposed to raising a `FunctionClauseError`)
  * atom keys for structs are supported (w/o `Access.key/1`)
  * integer keys are supported for lists and tuples (w/o `Access.at/1` or `Access.elem/1`)
  * an improper list's tail may be specified as the last element in the 'list'

  # Example

  By using Acs, you may specify which of these functions to override using
  the `:only` option (defaults to overriding all). Or you may forgo the use
  of this macro and override manually.

  ```
  defmodule A do
    use Acs
  end

  defmodule B do
    use Acs, only: get_in: 2
  end

  defmodule C do
    import Kernel, except: [get_in: 2]
    import Acs, only: [get_in: 2]
  end
  ```
  """

  import Kernel, except: [get_in: 2, update_in: 3, put_in: 3, get_and_update_in: 3, pop_in: 2]
  alias Acs.Improper

  @doc false
  defmacro __using__(opts) do
    default_opts = [get_in: 2, update_in: 3, put_in: 3, get_and_update_in: 3, pop_in: 2]

    opts =
      if Keyword.has_key?(opts, :only) do
        {keep, _} =
          opts
          |> Keyword.get(:only)
          |> (&Keyword.split(default_opts, &1)).()

        keep
      else
        default_opts
      end

    quote do
      import Kernel, except: unquote(opts)
      import Acs, only: unquote(opts)
    end
  end

  @doc """
  Gets a value and updates a nested structure.

  See `Kernel.get_and_update_in/3`.

  ## Examples

  Structs, lists, and tuples require less boilerplate to access.

    ```
    iex> data = [{nil, %ArgumentError{message: "foo"}}, nil]
    ...> lazy_keys = [0, 1, :message]
    ...> keys = [Access.at(0), Access.elem(1), Access.key(:message)]
    ...> fun = fn x -> {x, x <> "bar"} end
    ...> Acs.get_and_update_in(data, lazy_keys, fun) == Kernel.get_and_update_in(data, keys, fun)
    true
    ```

  Empty `keys` also return sensible defaults, instead of raising
  an exception.

    ```
    iex> Acs.get_and_update_in(%{}, [], fn x -> {x, Map.put(x, :a, 1)} end)
    {%{}, %{a: 1}}
    ```

  And the tail of an improper list can be accessed at element
  `length(data)` of the list.

    ```
    iex> Acs.get_and_update_in([:a, :b, :c | :d], [3], fn x -> {x, :e} end)
    {:d, [:a, :b, :c | :e]}
    ```
  """
  @spec get_and_update_in(Access.t(), keys, (term -> {get_value, update_value} | :pop)) ::
          {get_value, Access.t()}
        when keys: [term], update_value: term, get_value: term
  def get_and_update_in(data, keys, fun)
  def get_and_update_in(data, [], fun), do: fun.(data)

  def get_and_update_in(data, keys, fun) do
    Kernel.get_and_update_in(data, lazify(keys), fun)
  rescue
    _ -> {nil, data}
  end

  @doc """
  Gets a value from a nested structure.

  See `Kernel.get_in/2`.

  ## Examples

  Structs, lists, and tuples require less boilerplate to access.

    ```
    iex> data = [{nil, %ArgumentError{message: "foo"}}, nil]
    ...> lazy_keys = [0, 1, :message]
    ...> keys = [Access.at(0), Access.elem(1), Access.key(:message)]
    ...> Acs.get_in(data, lazy_keys) == Kernel.get_in(data, keys)
    true
    ```

  Empty `keys` also return sensible defaults, instead of raising
  an exception.

    ```
    iex> Acs.get_in(%{}, [])
    %{}
    ```

  And the tail of an improper list can be accessed at element
  `length(data)` of the list.

    ```
    iex> Acs.get_in([:a, :b, :c | :d], [3])
    :d
    ```
  """
  @spec get_in(Access.t(), keys :: [term]) :: Access.t() | nil
  def get_in(data, keys)
  def get_in(data, []), do: data

  def get_in(data, keys) do
    Kernel.get_in(data, lazify(keys))
  rescue
    _ -> nil
  end

  @doc """
  Updates a key in a nested structure.

  See `Kernel.update_in/3`.

  ## Examples

  Structs, lists, and tuples require less boilerplate to access.

    ```
    iex> data = [{nil, %ArgumentError{message: "foo"}}, nil]
    ...> lazy_keys = [0, 1, :message]
    ...> keys = [Access.at(0), Access.elem(1), Access.key(:message)]
    ...> fun = fn x -> x <> "bar" end
    ...> Acs.update_in(data, lazy_keys, fun) == Kernel.update_in(data, keys, fun)
    true
    ```

  Empty `keys` also return sensible defaults, instead of raising
  an exception.

    ```
    iex> Acs.update_in(%{}, [], &Map.put(&1, :a, 1))
    %{a: 1}
    ```

  And the tail of an improper list can be accessed at element
  `length(data)` of the list.

    ```
    iex> Acs.update_in([:a, :b, :c | :d], [3], fn _ -> :e end)
    [:a, :b, :c | :e]
    ```
  """
  @spec update_in(Access.t(), keys :: [term], (term -> term)) :: Access.t()
  def update_in(data, keys, fun)
  def update_in(data, [], fun), do: fun.(data)

  def update_in(data, keys, fun) do
    Kernel.update_in(data, lazify(keys), fun)
  rescue
    _ -> data
  end

  @doc """
  Puts a value in a nested structure.

  See `Kernel.put_in/3`.

  ## Examples

  Structs, lists, and tuples require less boilerplate to access.

    ```
    iex> data = [{nil, %ArgumentError{message: "foo"}}, nil]
    ...> lazy_keys = [0, 1, :message]
    ...> keys = [Access.at(0), Access.elem(1), Access.key(:message)]
    ...> Acs.put_in(data, lazy_keys, "bar") == Kernel.put_in(data, keys, "bar")
    true
    ```

  Empty `keys` also return sensible defaults, instead of raising
  an exception.

    ```
    iex> Acs.put_in([], [], :foo)
    [:foo]
    ```

  And the tail of an improper list can be accessed at element
  `length(data)` of the list.

    ```
    iex> Acs.put_in([:a, :b, :c | :d], [3], :e)
    [:a, :b, :c | :e]
    ```
  """
  @spec put_in(Access.t(), keys :: [term], value :: term) :: Access.t()
  def put_in(data, keys, value) do
    Kernel.put_in(data, lazify(keys), value)
  rescue
    _ -> data
  end

  @doc """
  Pops a key from the given nested structure.

  See `Kernel.pop_in/2`.

  ## Examples

  Structs, lists, and tuples require less boilerplate to access.

    ```
    iex> data = [{nil, %ArgumentError{message: "foo"}}, nil]
    ...> lazy_keys = [0, 1, :message]
    ...> keys = [Access.at(0), Access.elem(1), Access.key(:message)]
    ...> Acs.pop_in(data, lazy_keys) == Kernel.pop_in(data, keys)
    true
    ```

  Empty `keys` also return sensible defaults, instead of raising
  an exception.

    ```
    iex> Acs.pop_in(%{}, [])
    {nil, %{}}
    ```

  And the tail of an improper list can be accessed at element
  `length(data)` of the list.

    ```
    iex> Acs.pop_in([:a, :b, :c | :d], [3])
    [:a, :b, :c]
    ```
  """
  @spec pop_in(Access.t(), keys :: [term]) :: {term, Access.t()}
  def pop_in(data, keys) do
    Kernel.pop_in(data, lazify(keys))
  rescue
    _ -> {nil, data}
  end

  @doc false
  @spec lazify(keys) :: keys when keys: [term]
  def lazify(keys), do: Enum.map(keys, &lazy_keys/1)

  @doc false
  @spec lazy_keys(key :: term) :: Access.access_fun(Access.t(), term)
  def lazy_keys(key)

  def lazy_keys(fun) when is_function(fun, 3) do
    fun
  end

  def lazy_keys(i) when is_integer(i) do
    &lazy_accessor(i, &1, &2, &3)
  end

  def lazy_keys(key) when is_atom(key) do
    fn op, data, next ->
      Access.key(key).(op, data, next)
    end
  end

  def lazy_keys(key) do
    key
  end

  @spec lazy_accessor(integer, op, data, (term -> term)) ::
          {get_value, Access.container()} | :pop
        when data: term, get_value: term, op: :get | :get_and_update
  defp lazy_accessor(i, op, data, next) when is_list(data) and length(data) >= 0,
    do: Access.at(i).(op, data, next)

  defp lazy_accessor(i, op, data, next) when is_list(data),
    do: improper_accessor(i, op, data, next)

  defp lazy_accessor(i, op, data, next) when is_tuple(data), do: Access.elem(i).(op, data, next)
  defp lazy_accessor(i, op, data, next), do: Access.key(i).(op, data, next)

  @spec improper_accessor(integer, op, data, (term -> term)) ::
          {get_value, Access.container()} | :pop
        when data: term, get_value: term, op: :get | :get_and_update
  defp improper_accessor(i, op, data, next) do
    case Access.at(i).(op, Improper.to_proper(data), next) do
      {get, container} when length(container) >= 2 ->
        {get, Improper.to_improper(container)}

      otherwise ->
        otherwise
    end
  end
end
