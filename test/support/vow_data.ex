defmodule VowData do
  @moduledoc false

  @type stream_data(a) :: StreamData.t(a)
  @type stream_data :: stream_data(term)

  @spec spec(keyword) :: stream_data(Vow.t())
  def spec(opts \\ []) do
    child_data = Keyword.get(opts, :child_data, &non_recur_spec/1)
    parent_data = Keyword.get(opts, :parent_data, &recur_spec/2)

    StreamData.tree(
      child_data.(opts),
      &parent_data.(&1, opts)
    )
  end

  @spec non_recur_spec(keyword) :: stream_data(Vow.t())
  def non_recur_spec(opts \\ []) do
    StreamData.one_of([
      func(opts),
      pred_fun(opts),
      mapset(opts),
      range(opts),
      date_range(opts),
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

  @spec recur_spec(keyword) :: stream_data(Vow.t())
  def recur_spec(child_data \\ nil, opts \\ []) do
    child_data = process(child_data, opts)

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
      merge(child_data, opts),
      cat(child_data, opts),
      alt(child_data, opts),
      one_of(child_data, opts)
      # keys(child_data, opts),
      # ref(child_data, opts)
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

  @spec func(keyword) :: stream_data(Vow.Func.t())
  def func(opts \\ []) do
    pred_fun(opts)
    |> StreamData.map(&Vow.Func.new(&1, ~s<¯\_(ツ)_/¯>))
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

  @spec range(keyword) :: stream_data(Range.t())
  def range(_opts \\ []) do
    StreamData.tuple({
      StreamData.integer(),
      StreamData.integer()
    })
    |> StreamData.map(fn {min, max} -> min..max end)
  end

  @spec date_range(keyword) :: stream_data(Date.Range.t())
  def date_range(opts \\ []) do
    StreamData.tuple({
      date(opts),
      date(opts)
    })
    |> StreamData.map(fn {min, max} -> Date.range(min, max) end)
  end

  @spec date(keyword) :: stream_data(Date.t())
  def date(_opts \\ []) do
    StreamData.tuple({
      StreamData.integer(1970..2070),
      StreamData.integer(1..12),
      StreamData.integer(1..28)
    })
    |> StreamData.map(fn {y, m, d} ->
      Date.new(y, m, d) |> elem(1)
    end)
  end

  @spec time(keyword) :: stream_data(Time.t())
  def time(_opts \\ []) do
    StreamData.tuple({
      StreamData.integer(0..23),
      StreamData.integer(0..59),
      StreamData.integer(0..59),
      microseconds()
    })
    |> StreamData.map(fn {h, m, s, us} ->
      Time.new(h, m, s, us) |> elem(1)
    end)
  end

  @spec microseconds(keyword) :: stream_data({0..999_999, 0..6})
  def microseconds(_opts \\ []) do
    StreamData.integer(0..999_999)
    |> StreamData.map(fn i ->
      case Integer.digits(i) do
        [0] -> {0, 0}
        x -> {i, length(x)}
      end
    end)
  end

  @spec datetime(keyword) :: stream_data(DateTime.t())
  def datetime(opts \\ []) do
    StreamData.tuple({
      date(opts),
      time(opts)
    })
    |> StreamData.map(fn {d, t} ->
      %DateTime{
        calendar: t.calendar,
        day: d.day,
        hour: t.hour,
        microsecond: t.microsecond,
        minute: t.minute,
        month: d.month,
        second: t.second,
        std_offset: 0,
        time_zone: "Etc/UTC",
        utc_offset: 0,
        year: d.year,
        zone_abbr: "UTC"
      }
    end)
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
    |> StreamData.list_of(opts)
    |> StreamData.map(&Vow.also/1)
  end

  @spec amp(stream_data | nil, keyword) :: stream_data(Vow.Amp.t())
  def amp(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> StreamData.list_of(opts)
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

  @spec merge(stream_data | nil, keyword) :: stream_data(Vow.Merge.t())
  def merge(child_data \\ nil, opts \\ []) do
    merge_fun = Keyword.get(opts, :merge_fun)

    child_data
    |> process(opts)
    |> StreamData.list_of(opts)
    |> StreamData.map(&Vow.merge(&1, merge_fun))
  end

  @spec cat(stream_data | nil, keyword) :: stream_data(Vow.Cat.t())
  def cat(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_specs(opts)
    |> StreamData.map(&Vow.cat/1)
  end

  @spec alt(stream_data | nil, keyword) :: stream_data(Vow.Alt.t())
  def alt(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_specs(opts)
    |> StreamData.map(&Vow.alt/1)
  end

  @spec one_of(stream_data | nil, keyword) :: stream_data(Vow.OneOf.t())
  def one_of(child_data \\ nil, opts \\ []) do
    child_data
    |> process(opts)
    |> named_specs(opts)
    |> StreamData.map(&Vow.one_of/1)
  end

  @spec named_specs(stream_data(a), keyword) :: stream_data(keyword(a)) when a: term
  defp named_specs(data, opts) do
    StreamData.uniq_list_of(
      StreamData.tuple({StreamData.atom(:alphanumeric), data}),
      Keyword.merge(opts, min_length: 1, uniq_fun: &elem(&1, 0))
    )
  end

  @spec process(stream_data() | nil, keyword) :: stream_data()
  defp process(nil, opts), do: spec(opts)
  defp process(data, _opts), do: data
end
