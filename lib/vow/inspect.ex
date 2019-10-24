alias Vow.{Also, Alt, Amp, Cat, Keys, Maybe, Merge, Nilable, OneOf, OneOrMore, ZeroOrMore}

defimpl Inspect,
  for: [
    Also,
    Alt,
    Amp,
    Cat,
    Keys,
    Maybe,
    Merge,
    Nilable,
    OneOf,
    OneOrMore,
    ZeroOrMore,
    Vow.List,
    Vow.Map
  ] do
  @moduledoc false

  import Inspect.Algebra

  def inspect(spec, opts) do
    name = suffix(spec.__struct__)
    inspect_impl(name, spec, opts)
  end

  @spec inspect_impl(String.t(), Inspect.t(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  defp inspect_impl("OneOrMore", spec, opts), do: inspect_impl("OOM", spec, opts)
  defp inspect_impl("ZeroOrMore", spec, opts), do: inspect_impl("ZOM", spec, opts)

  defp inspect_impl("List", %Vow.List{} = spec, opts) do
    options = [break: :flex, separator: ","]

    coll =
      [spec.spec]
      |> append_if(not is_nil(non_default_range(spec)), non_default_range(spec))
      |> append_if(spec.distinct?, "distinct")

    container_doc("#List<", coll, ">", opts, &@protocol.inspect/2, options)
  end

  defp inspect_impl("Map", %Vow.Map{} = spec, opts) do
    options = [break: :flex, separator: ","]

    coll =
      [spec.key_spec, spec.value_spec]
      |> append_if(not is_nil(non_default_range(spec)), non_default_range(spec))
      |> append_if(spec.distinct?, "distinct")
      |> append_if(spec.conform_keys?, "conform_keys")

    container_doc("#Map<", coll, ">", opts, &@protocol.inspect/2, options)
  end

  defp inspect_impl(name, %{specs: []}, _opts) do
    "##{name}<>"
  end

  defp inspect_impl(name, %{specs: [{_, _} | _] = specs}, opts) do
    fun = fn {k, s}, os -> concat([to_string(k), "=", @protocol.inspect(s, os)]) end
    container_doc("##{name}<", specs, ">", opts, fun, break: :flex, separator: ",")
  end

  defp inspect_impl(name, %{specs: [_ | _] = specs}, opts) do
    container_doc("##{name}<", specs, ">", opts, &@protocol.inspect/2,
      break: :flex,
      separator: ","
    )
  end

  defp inspect_impl(name, %{spec: spec}, opts) do
    container_doc("##{name}<", [spec], ">", opts, &@protocol.inspect/2, break: :flex)
  end

  defp inspect_impl(_name, term, opts) do
    @protocol.inspect(term, opts)
  end

  @spec suffix(module) :: String.t()
  defp suffix(module) do
    to_string(module)
    |> String.split(".")
    |> List.last()
  end

  @spec append_if(list, boolean, term) :: list
  defp append_if(list, true, item), do: list ++ [item]
  defp append_if(list, false, _item), do: list

  @spec non_default_range(term) :: String.t() | nil
  defp non_default_range(%{max_length: max} = list) when not is_nil(max) do
    "#{list.min_length}..#{max}"
  end

  defp non_default_range(%{min_length: min}) when min > 0 do
    "#{min}.."
  end

  defp non_default_range(_list), do: nil
end
