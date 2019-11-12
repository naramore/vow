defmodule Vow.OneOf do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct [:vows]

  @type t :: %__MODULE__{
          vows: [{atom, Vow.t()}, ...]
        }

  @spec new([Vow.t()]) :: t
  def new(named_vows) do
    vow = %__MODULE__{vows: named_vows}

    if Vow.Cat.unique_keys?(named_vows) do
      vow
    else
      raise %Vow.DuplicateNameError{vow: vow}
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    @impl Vow.Conformable
    def conform(%@for{vows: [{k, vow}]}, path, via, route, val) do
      case @protocol.conform(vow, [k | path], via, route, val) do
        {:ok, conformed} -> {:ok, %{k => conformed}}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(%@for{vows: vows}, path, via, route, val)
        when is_list(vows) and length(vows) > 0 do
      Enum.reduce(vows, {:error, []}, fn
        _, {:ok, c} ->
          {:ok, c}

        {k, s}, {:error, pblms} ->
          case @protocol.conform(s, [k | path], via, route, val) do
            {:ok, conformed} -> {:ok, %{k => conformed}}
            {:error, problems} -> {:error, pblms ++ problems}
          end
      end)
    end

    @impl Vow.Conformable
    def unform(%@for{vows: vows} = vow, val) when is_map(val) do
      with [key] <- Map.keys(val),
           true <- Keyword.has_key?(vows, key) do
        @protocol.unform(Keyword.get(vows, key), Map.get(val, key))
      else
        _ -> {:error, %Vow.UnformError{vow: vow, val: val}}
      end
    end

    @impl Vow.Conformable
    def regex?(_vow), do: false
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(%@for{vows: vows}, opts) do
        vows
        |> Enum.reduce({:ok, []}, fn
          _, {:error, reason} ->
            {:error, reason}

          {_, v}, {:ok, acc} ->
            case @protocol.gen(v, opts) do
              {:error, reason} -> {:error, reason}
              {:ok, data} -> {:ok, [data | acc]}
            end
        end)
        |> case do
          {:error, reason} -> {:error, reason}
          {:ok, datas} -> {:ok, StreamData.one_of(datas)}
        end
      end
    end
  end
end
