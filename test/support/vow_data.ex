defmodule VowData do
  @moduledoc false

  @type stream_data(a) :: StreamData.t(a)
  @type stream_data :: stream_data(term)

  @spec vow(keyword) :: stream_data(Vow.t())
  def vow(opts \\ []) do
    child_data = Keyword.get(opts, :child_data, &non_recur_vow/1)
    parent_data = Keyword.get(opts, :parent_data, &recur_vow/2)

    StreamData.tree(
      child_data.(opts),
      &parent_data.(&1, opts)
    )
  end

  @spec non_recur_vow(keyword) :: stream_data(Vow.t())
  def non_recur_vow(opts \\ []) do
    StreamData.one_of([
      func(opts),
      pred_fun(opts),
      mapset(opts),
      StreamDataUtils.range(),
      StreamDataUtils.date_range(opts),
      StreamData.boolean(),
      StreamData.integer(),
      StreamData.float(),
      StreamData.atom(:alphanumeric),
      StreamData.binary(),
      StreamData.bitstring(),
      StreamData.iodata(),
      StreamData.iolist(),
      StreamData.string(:ascii)
    ])
  end

  @spec recur_vow(stream_data | nil, keyword) :: stream_data(Vow.t())
  def recur_vow(child_data \\ nil, opts \\ [])

  def recur_vow(nil, opts) do
    recur_vow(vow(opts), opts)
  end

  def recur_vow(child_data, opts) do
    StreamData.one_of([
      list_of(child_data, opts),
      maybe(child_data, opts),
      nilable(child_data, opts),
      oom(child_data, opts),
      zom(child_data, opts),
      map_of(child_data, opts),
      also(child_data, opts),
      amp(child_data, opts),
      list(child_data, opts),
      map(child_data, opts),
      tuple(child_data, opts),
      cat(child_data, opts),
      alt(child_data, opts),
      one_of(child_data, opts)
    ])
  end

  @spec regex_vow(stream_data | nil, keyword) :: stream_data(Vow.t())
  def regex_vow(child_data \\ nil, opts \\ []) do
    child_data = process(child_data, opts)

    StreamData.one_of([
      alt(child_data, opts),
      amp(child_data, opts),
      cat(child_data, opts),
      maybe(child_data, opts),
      oom(child_data, opts),
      zom(child_data, opts)
    ])
  end

  @spec pred_fun(keyword) :: stream_data((term -> boolean | no_return))
  def pred_fun(opts \\ []) do
    StreamData.frequency([
      {10, StreamData.constant(fn _ -> true end)},
      {5, StreamData.constant(fn _ -> false end)},
      {5, errored_pred_fun(opts)}
    ])
  end

  @spec errored_pred_fun(keyword) :: stream_data((term -> no_return))
  def errored_pred_fun(_opts \\ []) do
    StreamData.frequency([
      {10, StreamData.constant(fn _ -> raise %ArgumentError{} end)},
      {10, StreamData.constant(fn _ -> throw(:fail) end)},
      {5, StreamData.constant(fn _ -> exit(:normal) end)},
      {5, StreamData.constant(fn _ -> exit(:not_normal) end)}
    ])
  end

  @spec wrong_pred_fun() :: stream_data((term -> boolean))
  def wrong_pred_fun do
    StreamData.member_of([
      fn -> true end,
      fn _, _ -> true end,
      fn _, _, _ -> true end,
      fn _, _, _, _ -> true end
    ])
  end

  @spec func(keyword) :: stream_data(Vow.FunctionWrapper.t())
  def func(opts \\ []) do
    pred_fun(opts)
    |> StreamData.map(&Vow.FunctionWrapper.new(&1, ~s<¯\_(ツ)_/¯>))
  end

  @spec mapset(keyword) :: stream_data(MapSet.t())
  def mapset(opts \\ []) do
    if Keyword.has_key?(opts, :child_data) do
      Keyword.get(opts, :child_data)
    else
      StreamData.one_of([
        StreamData.integer(),
        StreamData.boolean(),
        StreamData.float(),
        StreamData.string(:ascii)
      ])
    end
    |> StreamData.list_of(opts)
    |> StreamData.map(&MapSet.new/1)
  end

  @spec subset(MapSet.t(), keyword) :: stream_data(MapSet.t())
  def subset(set, opts \\ []) do
    StreamData.member_of(set)
    |> (&mapset(Keyword.put(opts, :child_data, &1))).()
  end

  @spec list_of(stream_data | nil, keyword) :: stream_data(Vow.List.t())
  def list_of(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.map(&Vow.list_of(&1, opts))
  end

  @spec maybe(stream_data | nil, keyword) :: stream_data(Vow.Maybe.t())
  def maybe(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.map(&Vow.maybe/1)
  end

  @spec nilable(stream_data | nil, keyword) :: stream_data(Vow.Nilable.t())
  def nilable(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.map(&Vow.nilable/1)
  end

  @spec oom(stream_data | nil, keyword) :: stream_data(Vow.OneOrMore.t())
  def oom(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.map(&Vow.oom/1)
  end

  @spec zom(stream_data | nil, keyword) :: stream_data(Vow.ZeroOrMore.t())
  def zom(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.map(&Vow.zom/1)
  end

  @spec map_of(stream_data | nil, keyword) :: stream_data(Vow.Map.t())
  def map_of(child_data \\ nil, opts \\ []) do
    data = process(child_data, opts)

    StreamData.tuple({data, data})
    |> StreamData.map(fn {k, v} ->
      Vow.map_of(k, v, opts)
    end)
  end

  @spec also(stream_data | nil, keyword) :: stream_data(Vow.Also.t())
  def also(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_vows(opts)
    |> StreamData.map(&Vow.also/1)
  end

  @spec amp(stream_data | nil, keyword) :: stream_data(Vow.Amp.t())
  def amp(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_vows(opts)
    |> StreamData.map(&Vow.amp/1)
  end

  @spec list(stream_data | nil, keyword) :: stream_data(list)
  def list(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.list_of(opts)
  end

  @spec map(stream_data | nil, keyword) :: stream_data(map)
  def map(child_data \\ nil, opts \\ []) do
    data = process(child_data, opts)
    StreamData.map_of(data, data, opts)
  end

  @spec tuple(stream_data | nil, keyword) :: stream_data(tuple)
  def tuple(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.list_of(opts)
    |> StreamData.map(&List.to_tuple/1)
  end

  @spec merged(stream_data | nil, keyword) :: stream_data(Vow.Merge.t() | Vow.Map.t() | map)
  def merged(child_data \\ nil, opts \\ []) do
    StreamData.tree(
      process(child_data, opts),
      &merged_recur(&1, opts)
    )
  end

  @spec merged_recur(stream_data | nil, keyword) :: stream_data(Vow.Merge.t() | Vow.Map.t() | map)
  def merged_recur(child_data \\ nil, opts \\ []) do
    child_data = process(child_data, opts)

    StreamData.one_of([
      StreamData.map_of(StreamData.atom(:alphanumeric), child_data, opts),
      map(child_data, opts),
      merge(child_data, opts)
    ])
  end

  @spec merge(stream_data | nil, keyword) :: stream_data(Vow.Merge.t())
  def merge(child_data \\ nil, opts \\ []) do
    child_data =
      child_data
      |> process(opts)
      |> merged(opts)

    child_data
    |> named_vows(opts)
    |> StreamData.map(&Vow.merge/1)
  end

  @spec cat(stream_data | nil, keyword) :: stream_data(Vow.Cat.t())
  def cat(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_vows(opts)
    |> StreamData.map(&Vow.cat/1)
  end

  @spec alt(stream_data | nil, keyword) :: stream_data(Vow.Alt.t())
  def alt(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_vows(opts)
    |> StreamData.map(&Vow.alt/1)
  end

  @spec one_of(stream_data | nil, keyword) :: stream_data(Vow.OneOf.t())
  def one_of(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_vows(opts)
    |> StreamData.map(&Vow.one_of/1)
  end

  @spec named_vows(stream_data(), keyword) :: stream_data([any])
  defp named_vows(data, opts) do
    StreamData.uniq_list_of(
      StreamData.tuple({StreamData.atom(:alphanumeric), data}),
      Keyword.merge(opts, min_length: 1, uniq_fun: &elem(&1, 0))
    )
  end

  @spec process(stream_data() | nil, keyword) :: stream_data()
  defp process(nil, opts), do: vow(opts)
  defp process(data, _opts), do: data
end
