defprotocol Vow.Generatable do
  @moduledoc """
  TODO
  """

  @fallback_to_any true

  if Code.ensure_loaded?(StreamData) do
    @type generator :: StreamData.t(term)
  else
    @type generator :: term
  end

  @typedoc """
  """
  @type gen_fun :: (() -> generator)

  @typedoc """
  """
  @type gen_opt :: {:ignore_warn?, boolean}

  @doc """
  """
  @spec gen(t, [gen_opt]) :: {:ok, generator} | {:error, reason :: term}
  def gen(generatable, opts \\ [])
end

if Code.ensure_loaded?(StreamData) do
  defimpl Vow.Generatable, for: StreamData do
    @moduledoc false

    @impl Vow.Generatable
    def gen(stream_data, _opts), do: {:ok, stream_data}
  end

  defimpl Vow.Generatable, for: Function do
    @moduledoc false
    alias Vow.Utils
    import StreamData
    import StreamDataUtils

    @impl Vow.Generatable
    def gen(vow, opts) when is_function(vow, 1) do
      if Map.has_key?(supported_functions(), vow) do
        {:ok, Map.get(supported_functions(), vow)}
      else
        ignore_warn? = Keyword.get(opts, :ignore_warn?, false)
        _ = Utils.no_override_warn(vow, ignore_warn?)

        {:ok, filter(string(:printable), vow)}
      end
    end

    def gen(vow, _opts) do
      {:error, {:invalid_function_arity, vow}}
    end

    @spec supported_functions() :: %{optional((term -> boolean)) => StreamData.t(term)}
    defp supported_functions do
      %{
        &is_boolean/1 => boolean(),
        &is_atom/1 => atom(:alphanumeric),
        &is_binary/1 => binary(),
        &is_bitstring/1 => bitstring(),
        &is_float/1 => float(),
        &is_integer/1 => integer(),
        &is_number/1 => one_of([integer(), float()]),
        &is_nil/1 => constant(nil),
        &is_map/1 => map_of(simple(), simple()),
        &is_list/1 => list_of(simple()),
        &is_tuple/1 => tuple_of(simple())
      }
    end
  end

  defimpl Vow.Generatable, for: List do
    @moduledoc false

    @impl Vow.Generatable
    def gen(vow, opts) do
      vow
      |> Enum.reduce({:ok, []}, fn
        _, {:error, reason} ->
          {:error, reason}

        v, {:ok, acc} ->
          case @protocol.gen(v, opts) do
            {:error, reason} -> {:error, reason}
            {:ok, data} -> {:ok, [data | acc]}
          end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        {:ok, data} -> {:ok, StreamData.fixed_list(Enum.reverse(data))}
      end
    end
  end

  defimpl Vow.Generatable, for: Tuple do
    @moduledoc false

    @impl Vow.Generatable
    def gen(vow, opts) do
      vow
      |> Tuple.to_list()
      |> Enum.reduce({:ok, []}, fn
        _, {:error, reason} ->
          {:error, reason}

        v, {:ok, acc} ->
          case @protocol.gen(v, opts) do
            {:error, reason} -> {:error, reason}
            {:ok, data} -> {:ok, [data | acc]}
          end
      end)
      |> case do
        {:error, reason} ->
          {:error, reason}

        {:ok, data} ->
          data
          |> Enum.reverse()
          |> List.to_tuple()
          |> StreamData.tuple()
          |> (&{:ok, &1}).()
      end
    end
  end

  defimpl Vow.Generatable, for: Map do
    @moduledoc false

    @impl Vow.Generatable
    def gen(vow, opts) do
      vow
      |> Enum.reduce({:ok, %{}}, fn
        _, {:error, reason} ->
          {:error, reason}

        {k, v}, {:ok, acc} ->
          case @protocol.gen(v, opts) do
            {:error, reason} -> {:error, reason}
            {:ok, data} -> {:ok, Map.put(acc, k, data)}
          end
      end)
      |> case do
        {:error, reason} -> {:error, reason}
        {:ok, data} -> {:ok, StreamData.fixed_map(data)}
      end
    end
  end

  defimpl Vow.Generatable, for: MapSet do
    @moduledoc false

    @impl Vow.Generatable
    def gen(%MapSet{map: %{}}, _opts),
      do: {:ok, StreamData.constant(MapSet.new([]))}

    def gen(vow, _opts) do
      {:ok,
       StreamData.one_of([
         StreamData.member_of(vow),
         StreamData.map(
          StreamData.uniq_list_of(StreamData.member_of(vow)),
          &MapSet.new/1
         )
       ])}
    end
  end

  defimpl Vow.Generatable, for: Regex do
    @moduledoc false
    alias Vow.Utils
    import StreamData

    @impl Vow.Generatable
    def gen(vow, opts) do
      ignore_warn? = Keyword.get(opts, :ignore_warn?, false)
      _ = Utils.no_override_warn(vow, ignore_warn?)

      {:ok, filter(string(:printable), &Regex.match?(vow, &1))}
    end
  end

  defimpl Vow.Generatable, for: Range do
    @moduledoc false

    @impl Vow.Generatable
    def gen(min..max, _opts) do
      {:ok,
       StreamData.one_of([
         StreamData.integer(min..max),
         StreamDataUtils.range(min..max)
       ])}
    end
  end

  defimpl Vow.Generatable, for: Date.Range do
    @moduledoc false

    @impl Vow.Generatable
    def gen(vow, _opts) do
      {:ok,
       StreamData.one_of([
         StreamDataUtils.date(range: vow),
         StreamDataUtils.date_range(range: vow)
       ])}
    end
  end

  defimpl Vow.Generatable, for: Any do
    @moduledoc false

    @impl Vow.Generatable
    def gen(%{__struct__: mod} = vow, opts) do
      case @protocol.Map.gen(Map.delete(vow, :__struct__), opts) do
        {:error, reason} -> {:error, reason}
        {:ok, data} -> {:ok, StreamData.map(data, &Map.put(&1, :__struct__, mod))}
      end
    end

    def gen(vow, _opts) do
      StreamData.constant(vow)
    end
  end
end
