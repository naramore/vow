defmodule Vow.Utils do
  @moduledoc false
  require Logger

  @spec no_override_warn(Vow.t(), boolean) :: :ok
  def no_override_warn(vow, ignore_warn? \\ false)
  def no_override_warn(_vow, true), do: :ok

  def no_override_warn(vow, false) do
    Logger.warn(fn ->
      """
      The following vow:

      #{vow}

      has been identified as having a 'problematic' default generator
      involving a broad generator (e.g. string, term) and a
      potentially strict filter, or potentially unbounded recursive
      behavior.

      It's advisable to explicitly override this default generator as the
      filter (if applicable) is likely to raise, or the recursive behavior
      could result in an infinite loop.

      See the `Vow.gen/2` documentation for more details.
      """
    end)
  end

  @spec init_path([any]) :: [any, ...]
  def init_path(path) do
    path ++ [0]
  end

  @spec uninit_path([term]) :: [term]
  def uninit_path(path) do
    List.delete_at(path, length(path) - 1)
  end

  @spec inc_path([term]) :: [term]
  def inc_path(path) do
    List.update_at(path, length(path) - 1, fn i -> i + 1 end)
  end

  @spec append(list | term, list | term) :: list
  def append([], []), do: []
  def append([_ | _] = l, []), do: l
  def append([], [_ | _] = r), do: r
  def append([_ | _] = l, [_ | _] = r), do: l ++ r
  def append(l, r) when is_list(r), do: [l | r]
  def append(l, r) when is_list(l), do: l ++ [r]

  @spec distinct?(Enum.t()) :: boolean
  def distinct?(enum) do
    count = enum |> Enum.count()
    unique_count = enum |> Enum.uniq() |> Enum.count()
    count == unique_count
  end

  @spec compatible_form?([any], [any]) :: boolean
  def compatible_form?(list, value) do
    case {improper_info(list), improper_info(value)} do
      {{true, n}, {true, n}} -> true
      {{false, n}, {false, n}} -> true
      _ -> false
    end
  end

  @spec improper_info(list, non_neg_integer) :: {boolean, non_neg_integer}
  def improper_info(list, n \\ 0)
  def improper_info([], n), do: {false, n}
  def improper_info([_ | t], n) when is_list(t), do: improper_info(t, n + 1)
  def improper_info(_, n), do: {true, n}

  @spec append_if(list, boolean, term) :: list
  def append_if(list, true, item), do: list ++ [item]
  def append_if(list, false, _item), do: list

  @spec non_default_range(map) :: String.t() | nil
  def non_default_range(%{max_length: max, min_length: min}) when not is_nil(max) do
    "#{min}..#{max}"
  end

  def non_default_range(%{min_length: min}) when not is_nil(min) and min > 0 do
    "#{min}.."
  end

  def non_default_range(_), do: nil

  defmodule AccessShortcut do
    @moduledoc false

    defmacro __using__(opts) do
      type = Keyword.get(opts, :type, :key_based)

      [
        quote do
          @behaviour Access
        end,
        build(type)
      ]
    end

    @spec build(atom) :: Macro.t()
    defp build(:passthrough) do
      quote do
        @impl Access
        def fetch(%{vow: vow}, key) do
          Access.fetch(vow, key)
        end

        @impl Access
        def pop(%{vow: vow}, key) do
          Access.pop(vow, key)
        end

        @impl Access
        def get_and_update(%{vow: vow}, key, fun) do
          Access.get_and_update(vow, key, fun)
        end
      end
    end

    defp build(:key_based) do
      quote do
        @impl Access
        def fetch(%{vows: vows}, key) do
          Keyword.fetch(vows, key)
        end

        @impl Access
        def pop(%{vows: vows}, key) do
          Keyword.pop(vows, key)
        end

        @impl Access
        def get_and_update(%{vows: vows}, key, fun) do
          Keyword.get_and_update(vows, key, fun)
        end
      end
    end
  end
end
