defmodule Vow.Map do
  @moduledoc false
  @behaviour Access

  defstruct key_vow: nil,
            value_vow: nil,
            min_length: 0,
            max_length: nil,
            conform_keys?: false

  @type t :: %__MODULE__{
          key_vow: Vow.t(),
          value_vow: Vow.t(),
          min_length: non_neg_integer,
          max_length: non_neg_integer | nil,
          conform_keys?: boolean
        }

  @spec new(Vow.t(), Vow.t(), non_neg_integer, non_neg_integer | nil, boolean) :: t
  def new(
        key_vow,
        value_vow,
        min_length,
        max_length,
        conform_keys?
      ) do
    %__MODULE__{
      key_vow: key_vow,
      value_vow: value_vow,
      min_length: min_length,
      max_length: max_length,
      conform_keys?: conform_keys?
    }
  end

  @impl Access
  def fetch(%__MODULE__{} = vow, key) do
    case {Access.fetch(vow.key_value, key), Access.fetch(vow.value_vow, key)} do
      {{:ok, kval}, {:ok, vval}} -> {:ok, [kval, vval]}
      {:error, :error} -> :error
      {{:ok, val}, _} -> {:ok, val}
      {_, {:ok, val}} -> {:ok, val}
    end
  end

  @impl Access
  def pop(%__MODULE__{} = vow, key) do
    case {Access.pop(vow.key_value, key), Access.pop(vow.value_vow, key)} do
      {{nil, _}, {nil, _}} ->
        {nil, vow}

      {{nil, _}, {val, data}} ->
        {val, Map.put(vow, :value_vow, data)}

      {{val, data}, {nil, _}} ->
        {val, Map.put(vow, :key_vow, data)}

      {{kval, kdata}, {vval, vdata}} ->
        {[kval, vval], Map.merge(vow, %{key_vow: kdata, value_vow: vdata})}
    end
  end

  @impl Access
  def get_and_update(%__MODULE__{} = vow, key, fun) do
    case Access.get_and_update(vow.key_vow, key, fun) do
      {nil, _} ->
        case Access.get_and_update(vow.value_vow, key, fun) do
          {nil, _} -> {nil, vow}
          {vget, vupdate} -> {vget, Map.put(vow, :value_vow, vupdate)}
        end

      {kget, kupdate} ->
        case Access.get_and_update(vow.value_vow, key, fun) do
          {nil, _} ->
            {kget, Map.put(vow, :key_vow, kupdate)}

          {vget, vupdate} ->
            {[kget, vget], Map.merge(vow, %{key_vow: kupdate, value_vow: vupdate})}
        end
    end
  end

  defimpl Vow.Conformable do
    @moduledoc false

    import Vow.FunctionWrapper
    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(vow, vow_path, via, value_path, value) when is_map(value) do
      value
      |> Enum.map(fn {k, v} ->
        conform_key_value(vow, vow_path, via, value_path, {k, v})
      end)
      |> Enum.reduce({:ok, []}, fn
        {:ok, c}, {:ok, cs} -> {:ok, [c | cs]}
        {:error, ps}, {:ok, _} -> {:error, ps}
        {:ok, _}, {:error, ps} -> {:error, ps}
        {:error, ps}, {:error, pblms} -> {:error, pblms ++ ps}
      end)
      |> ConformError.add_problems(size_problems(vow, vow_path, via, value_path, value), true)
      |> case do
        {:ok, conformed} -> {:ok, Enum.into(conformed, %{})}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_vow, vow_path, via, value_path, value) do
      {:error, [ConformError.new_problem(&is_map/1, vow_path, via, value_path, value)]}
    end

    @impl Vow.Conformable
    def unform(%@for{key_vow: kv, value_vow: vv} = vow, value)
        when is_map(value) do
      Enum.reduce(value, {:ok, %{}}, fn
        _, {:error, reason} ->
          {:error, reason}

        {k, v}, {:ok, acc} ->
          with {:ok, uv} <- @protocol.unform(vv, v),
               {true, _} <- {vow.conform_keys?, uv},
               {:ok, uk} <- @protocol.unform(kv, v) do
            {:ok, Map.put(acc, uk, uv)}
          else
            {false, uv} -> {:ok, Map.put(acc, k, uv)}
            {:error, reason} -> {:error, reason}
          end
      end)
    end

    def unform(vow, value) do
      {:error, %Vow.UnformError{vow: vow, value: value}}
    end

    @spec conform_key_value(@for.t, [term], [Vow.Ref.t()], [term], {term, term}) ::
            {:ok, term} | {:error, [ConformError.Problem.t()]}
    defp conform_key_value(
           %@for{conform_keys?: conform_keys?} = vow,
           vow_path,
           via,
           value_path,
           {k, v}
         ) do
      {
        @protocol.conform(vow.key_vow, vow_path, via, value_path, k),
        @protocol.conform(vow.value_vow, vow_path, via, value_path ++ [k], v)
      }
      |> case do
        {{:ok, ck}, {:ok, cv}} ->
          {:ok, {if(conform_keys?, do: ck, else: k), cv}}

        {{:error, kps}, {:error, vps}} ->
          {:error, vps ++ kps}

        {_, {:error, vps}} ->
          {:error, vps}

        {{:error, kps}, _} ->
          {:error, kps}
      end
    end

    @spec size_problems(@for.t, [term], [Vow.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    defp size_problems(vow, vow_path, via, value_path, value) do
      case {vow.min_length, vow.max_length} do
        {min, _max} when map_size(value) < min ->
          [
            ConformError.new_problem(
              wrap(&(map_size(&1) >= min), min: min),
              vow_path,
              via,
              value_path,
              value
            )
          ]

        {_min, max} when not is_nil(max) and map_size(value) > max ->
          [
            ConformError.new_problem(
              wrap(&(map_size(&1) <= max), max: max),
              vow_path,
              via,
              value_path,
              value
            )
          ]

        _ ->
          []
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow, opts) do
        with {:ok, key_gen} <- @protocol.gen(vow.key_vow, opts),
             {:ok, value_gen} <- @protocol.gen(vow.value_vow, opts),
             {opts, _} <- Map.from_struct(vow) |> Map.split([:min_length, :max_length]) do
          {:ok,
           StreamData.map_of(
             key_gen,
             value_gen,
             Enum.into(opts, [])
           )}
        else
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end
