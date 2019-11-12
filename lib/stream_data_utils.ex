if Code.ensure_loaded?(StreamData) do
  defmodule StreamDataUtils.Function do
    @moduledoc false

    defmacro __before_compile__(_env) do
      [
        quote do
          @doc false
          @spec build_fun(arity, a) :: (... -> a) when a: term
        end
        | Enum.map(0..255, fn arity ->
            quote do
              defp build_fun(unquote(arity), ret) do
                StreamDataUtils.Function.build_fun(fn -> ret end, unquote(arity), __MODULE__)
              end
            end
          end)
      ]
    end

    @spec build_fun(Macro.t(), arity, module) :: Macro.t()
    def build_fun(fun_ast, 0, _mod), do: fun_ast

    def build_fun(fun_ast, arity, mod) do
      Macro.prewalk(fun_ast, fn
        {:->, meta, [_, ret]} ->
          {:->, meta, [build_arity(arity, mod), ret]}

        otherwise ->
          otherwise
      end)
    end

    @spec build_arity(arity, module) :: [Macro.t()]
    def build_arity(arity, mod) do
      fn -> Macro.var(:_, mod) end
      |> Stream.repeatedly()
      |> Enum.take(arity)
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.ModuleDependencies
  defmodule StreamDataUtils do
    @moduledoc """
    TODO
    """

    @before_compile StreamDataUtils.Function
    import StreamData
    import Kernel, except: [struct: 2]

    @typedoc """
    """
    @type t(a) :: StreamData.t(a)

    @typedoc """
    """
    @type t :: t(term)

    @typedoc """
    """
    @type list_opt ::
            {:min_length, non_neg_integer}
            | {:max_length, non_neg_integer}
            | {:length, non_neg_integer | Range.t()}

    @doc """
    """
    @spec simple() :: t
    def simple do
      one_of([
        boolean(),
        integer(),
        float(),
        string(:printable),
        bitstring(),
        binary(),
        atom(),
        byte(),
        iodata(),
        iolist()
      ])
    end

    @doc """
    """
    @spec function(arity, t) :: t
    def function(arity, return_data),
      do: map(return_data, &build_fun(arity, &1))

    @doc """
    """
    @spec lazy(t) :: Macro.t()
    defmacro lazy(data) do
      quote do
        sized(fn _ -> unquote(data) end)
      end
    end

    @doc """
    """
    @spec struct(module, map | keyword) :: t(struct)
    def struct(module, data) do
      data
      |> fixed_map()
      |> map(&Kernel.struct(module, &1))
    end

    @doc """
    """
    @spec tuple_of(t, [list_opt]) :: t(tuple)
    def tuple_of(data, opts \\ []) do
      data
      |> list_of(opts)
      |> map(&List.to_tuple/1)
    end

    @doc """
    Equivalent to `StreamData.atom(:alphanumeric)`.
    """
    @spec atom() :: t(atom)
    def atom, do: atom(:alphanumeric)

    defdelegate pos_integer(), to: StreamData, as: :positive_integer

    @doc """
    """
    @spec non_neg_integer() :: t(non_neg_integer)
    def non_neg_integer do
      # NOTE: imperfect, should probably just Fork + PR StreamData better implement partially bounded integers
      frequency([
        {1, constant(0)},
        {100, pos_integer()}
      ])
    end

    @doc """
    """
    @spec neg_integer() :: t(neg_integer)
    def neg_integer,
      do: map(pos_integer(), &(-&1))

    @doc """
    """
    @spec keyword_of(t, [list_opt]) :: t([any])
    def keyword_of(value_data, options \\ []) do
      list_of(tuple({atom(), value_data}), options)
    end

    @typedoc """
    """
    @type datetime_opt ::
            {:min_datetime, DateTime.t()}
            | {:max_datetime, DateTime.t()}

    @doc """
    """
    @spec datetime([datetime_opt]) :: t(DateTime.t())
    def datetime(options \\ []) do
      {date_opts, time_opts} = split_date_and_time_opts(options)

      bind(date(date_opts), fn d ->
        time_gen =
          case date_edgecase(d, date_opts) do
            :max -> time(Keyword.delete(time_opts, :min_time))
            :min -> time(Keyword.delete(time_opts, :max_time))
            nil -> time()
          end

        map(time_gen, fn t -> datetime_combine_utc(d, t) end)
      end)
    end

    @doc """
    """
    @spec date_range([date_opt]) :: t(Date.Range.t())
    def date_range(opts \\ []) do
      map(tuple({date(opts), date(opts)}), fn {d1, d2} ->
        Date.range(d1, d2)
      end)
    end

    @typedoc """
    """
    @type date_opt ::
            {:min_date, Date.t()}
            | {:max_date, Date.t()}
            | {:range, Date.Range.t()}

    @doc """
    """
    @spec date([date_opt]) :: t(Date.t())
    def date(options \\ []) do
      options
      |> get_date_range()
      |> date_mapper()
    end

    @spec date_mapper(Date.Range.t() | {integer | nil, integer | nil}) :: t(Date.t())
    defp date_mapper(%Date.Range{} = date_range), do: member_of(date_range)
    defp date_mapper({nil, nil}), do: map(integer(), &Date.add(Date.utc_today(), &1))
    defp date_mapper({nil, max}), do: map(non_neg_integer(), &Date.add(max, -&1))
    defp date_mapper({min, nil}), do: map(non_neg_integer(), &Date.add(min, &1))

    @sdiv 60
    @mdiv 60
    @usdiv 1_000_000
    @time_max Time.diff(
                ~T[23:59:59.999999],
                ~T[00:00:00.000000],
                :microsecond
              )

    @typedoc """
    """
    @type time_opt ::
            {:min_time, Time.t()}
            | {:max_time, Time.t()}

    @doc """
    """
    @spec time([time_opt]) :: t(Time.t())
    def time(options \\ []) do
      {min, max} = get_time_range(options)
      map(integer(min..max), &time_mapper/1)
    end

    @spec time_mapper(integer) :: Time.t()
    defp time_mapper(i) do
      {min_left, s} = {div(i, @sdiv), rem(i, @sdiv)}
      {hr_left, m} = {div(min_left, @mdiv), rem(min_left, @mdiv)}
      {h, us} = {div(hr_left, @usdiv), rem(hr_left, @usdiv)}
      {:ok, time} = Time.new(h, m, s, {us, precision(us)})
      time
    end

    @doc """
    """
    @spec range() :: t(Range.t())
    def range do
      map(
        tuple({integer(), integer()}),
        fn {i1, i2} -> i1..i2 end
      )
    end

    @doc """
    """
    @spec range(Range.t()) :: t(Range.t())
    def range(min..max) do
      map(
        tuple({integer(min..max), integer(min..max)}),
        fn {i1, i2} -> i1..i2 end
      )
    end

    @doc false
    @spec precision(0..999_999) :: 0..6
    defp precision(microseconds) do
      case Integer.digits(microseconds) do
        [0] -> 0
        ds -> length(ds)
      end
    end

    @doc false
    @spec split_date_and_time_opts([datetime_opt]) :: {[date_opt], [time_opt]}
    defp split_date_and_time_opts(opts) do
      with {:min, nil} <- {:min, Keyword.get(opts, :min_datetime)},
           {:max, nil} <- {:max, Keyword.get(opts, :max_datetime)} do
        {[], []}
      else
        {:max, max} ->
          {[max_date: DateTime.to_date(max)], [max_time: DateTime.to_time(max)]}

        {:min, min} ->
          case Keyword.get(opts, :max_datetime) do
            nil ->
              {[min_date: DateTime.to_date(min)], [min_time: DateTime.to_time(min)]}

            max ->
              {[min_date: DateTime.to_date(min), max_date: DateTime.to_date(max)],
               [min_time: DateTime.to_time(min), max_time: DateTime.to_time(max)]}
          end
      end
    end

    @doc false
    @spec date_edgecase(Date.t(), [date_opt]) :: :max | :min | nil
    defp date_edgecase(date, opts) do
      case get_date_range(opts) do
        %Date.Range{first: ^date, last: max} when max >= date -> :min
        %Date.Range{first: min, last: ^date} when date >= min -> :max
        %Date.Range{first: ^date} -> :max
        %Date.Range{last: ^date} -> :min
        {^date, _} -> :min
        {_, ^date} -> :max
        _ -> nil
      end
    end

    @doc false
    @spec datetime_combine_utc(Date.t(), Time.t()) :: DateTime.t()
    defp datetime_combine_utc(date, time) do
      %DateTime{
        calendar: time.calendar,
        day: date.day,
        hour: time.hour,
        microsecond: time.microsecond,
        minute: time.minute,
        month: date.month,
        second: time.second,
        std_offset: 0,
        time_zone: "Etc/UTC",
        utc_offset: 0,
        year: date.year,
        zone_abbr: "UTC"
      }
    end

    @doc false
    @spec get_date_range(keyword) ::
            {Date.t(), nil} | {nil, Date.t()} | {nil, nil} | Date.Range.t()
    defp get_date_range(opts) do
      if Keyword.has_key?(opts, :range) do
        Keyword.get(opts, :range)
      else
        case {Keyword.get(opts, :min_date), Keyword.get(opts, :max_date)} do
          {nil, nil} -> {nil, nil}
          {nil, max} -> {nil, max}
          {min, nil} -> {min, nil}
          {min, max} -> Date.range(min, max)
        end
      end
    end

    @doc false
    @spec get_time_range(keyword) :: {non_neg_integer, non_neg_integer}
    defp get_time_range(opts) do
      min = Keyword.get(opts, :min_time, 0)
      max = Keyword.get(opts, :max_time, @time_max)
      {min, max}
    end
  end

  defmodule StreamDataUtils.Tree do
    @moduledoc """
    TODO
    """
  end
end
