defmodule Acs.Improper do
  @moduledoc false

  @spec to_proper(nonempty_maybe_improper_list()) :: [any, ...]
  def to_proper([h | t]) when is_list(t), do: [h | to_proper(t)]
  def to_proper([h | t]), do: [h | [t]]

  @spec improper_get(nonempty_improper_list(term, term) | term, integer) :: term | nil
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

  @spec improper_length(nonempty_improper_list(term, term), non_neg_integer) :: non_neg_integer
  def improper_length(list, len \\ 0)

  def improper_length([_ | t], len) when is_list(t),
    do: improper_length(t, len + 1)

  def improper_length(_, len), do: len + 2

  @spec proper_list?(term) :: boolean
  def proper_list?([]), do: true
  def proper_list?([_ | t]) when is_list(t), do: proper_list?(t)
  def proper_list?(_), do: false
end

defmodule Acs do
  @moduledoc """
  TODO
  """

  import Kernel, except: [get_in: 2, update_in: 3, put_in: 3, get_and_update_in: 3]
  alias Acs.Improper

  @doc false
  defmacro __using__(opts) do
    default_opts = [get_in: 2, update_in: 3, put_in: 3, get_and_update_in: 3]

    opts =
      if Keyword.has_key?(opts, :only) do
        {keep, _} =
          Keyword.get(opts, :only)
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
  """
  @spec get_and_update_in(Access.t(), keys, (term -> {get_value, update_value} | :pop)) ::
          {get_value, Access.t()}
        when keys: [term], update_value: term, get_value: term
  def get_and_update_in(data, [], fun), do: fun.(data)

  def get_and_update_in(data, keys, fun) do
    Kernel.get_and_update_in(data, lazify(keys), fun)
  rescue
    _ -> {nil, data}
  end

  @doc """
  """
  @spec get_in(Access.t(), keys :: [term]) :: Access.t() | nil
  def get_in(data, []), do: data

  def get_in(data, keys) do
    Kernel.get_in(data, lazify(keys))
  rescue
    _ -> nil
  end

  @doc """
  """
  @spec update_in(Access.t(), keys :: [term], (term -> term)) :: Access.t()
  def update_in(data, [], fun), do: fun.(data)

  def update_in(data, keys, fun) do
    Kernel.update_in(data, lazify(keys), fun)
  rescue
    _ -> data
  end

  @doc """
  """
  @spec put_in(Access.t(), keys :: [term], value :: term) :: Access.t()
  def put_in(data, keys, value) do
    Kernel.put_in(data, lazify(keys), value)
  rescue
    _ -> data
  end

  @doc false
  @spec lazify(path) :: path when path: [term]
  def lazify(path), do: Enum.map(path, &lazy_keys/1)

  @doc false
  @spec lazy_keys(term) :: Access.access_fun(Access.t(), term)
  def lazy_keys(fun) when is_function(fun, 3), do: fun

  def lazy_keys(i) when is_integer(i) do
    fn
      op, data, next when is_list(data) and length(data) >= 0 ->
        Access.at(i).(op, data, next)

      op, data, next when is_list(data) ->
        Access.at(i).(op, Improper.to_proper(data), next)

      op, data, next when is_tuple(data) ->
        Access.elem(i).(op, data, next)

      op, data, next ->
        Access.key(i).(op, data, next)
    end
  end

  def lazy_keys(key) when is_atom(key) do
    fn op, data, next ->
      Access.key(key).(op, data, next)
    end
  end

  def lazy_keys(key), do: key
end
