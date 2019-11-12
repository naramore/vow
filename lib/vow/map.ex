defmodule Vow.Map do
  @moduledoc false
  use Vow.Utils.AccessShortcut

  defstruct key_vow: nil,
            val_vow: nil,
            min_length: 0,
            max_length: nil,
            conform_keys?: false

  @type t :: %__MODULE__{
          key_vow: Vow.t(),
          val_vow: Vow.t(),
          min_length: non_neg_integer,
          max_length: non_neg_integer | nil,
          conform_keys?: boolean
        }

  @spec new(Vow.t(), Vow.t(), non_neg_integer, non_neg_integer | nil, boolean) :: t
  def new(
        key_vow,
        val_vow,
        min_length,
        max_length,
        conform_keys?
      ) do
    %__MODULE__{
      key_vow: key_vow,
      val_vow: val_vow,
      min_length: min_length,
      max_length: max_length,
      conform_keys?: conform_keys?
    }
  end

  @impl Access
  def fetch(%__MODULE__{} = vow, key)
      when key in [:key_vow, :val_vow] do
    Map.fetch(vow, key)
  end

  def fetch(%__MODULE__{}, _), do: :error

  @impl Access
  def pop(%__MODULE__{} = vow, key)
      when key in [:key_vow, :val_vow] do
    Map.pop(vow, key)
  end

  def pop(%__MODULE__{} = vow, _), do: {nil, vow}

  @impl Access
  def get_and_update(%__MODULE__{} = vow, key, fun)
      when key in [:key_vow, :val_vow] do
    Map.get_and_update(vow, key, fun)
  end

  def get_and_update(%__MODULE__{} = vow, _key, _fun), do: {nil, vow}

  defimpl Vow.Conformable do
    @moduledoc false

    import Vow.FunctionWrapper
    alias Vow.ConformError

    @impl Vow.Conformable
    def conform(vow, path, via, route, val) when is_map(val) do
      val
      |> Enum.map(&conform_key_value(vow, path, via, route, &1))
      |> Enum.reduce({:ok, []}, &conform_reducer/2)
      |> ConformError.add_problems(size_problems(vow, path, via, route, val), true)
      |> case do
        {:ok, conformed} -> {:ok, Enum.into(conformed, %{})}
        {:error, problems} -> {:error, problems}
      end
    end

    def conform(_vow, path, via, route, val) do
      {:error, [ConformError.new_problem(&is_map/1, path, via, route, val)]}
    end

    @impl Vow.Conformable
    def unform(vow, val) when is_map(val) do
      Enum.reduce(val, {:ok, %{}}, &unform_reducer(&1, &2, vow))
    end

    def unform(vow, val) do
      {:error, %Vow.UnformError{vow: vow, val: val}}
    end

    @impl Vow.Conformable
    def regex?(_vow), do: false

    @spec conform_key_value(@for.t, [term], [Vow.Ref.t()], [term], {term, term}) ::
            {:ok, term} | {:error, [ConformError.Problem.t()]}
    defp conform_key_value(vow, path, via, route, {k, v}) do
      case conform_kv(vow, path, via, route, {k, v}) do
        {{:ok, ck}, {:ok, cv}} ->
          {:ok, {if(vow.conform_keys?, do: ck, else: k), cv}}

        {{:error, kps}, {:error, vps}} ->
          {:error, vps ++ kps}

        {_, {:error, vps}} ->
          {:error, vps}

        {{:error, kps}, _} ->
          {:error, kps}
      end
    end

    @spec conform_kv(type, Vow.t(), [term], [Vow.Ref.t()], [term], {term, term}) ::
            @protocol.result | {@protocol.result, @protocol.result}
          when type: :key | :val | :both
    defp conform_kv(type \\ :both, vow, path, via, route, kv)

    defp conform_kv(:both, vow, path, via, route, kv) do
      {
        conform_kv(:key, vow, path, via, route, kv),
        conform_kv(:val, vow, path, via, route, kv)
      }
    end

    defp conform_kv(:key, vow, path, via, route, {k, _}) do
      @protocol.conform(vow.key_vow, [:key_vow | path], via, route, k)
    end

    defp conform_kv(:val, vow, path, via, route, {k, v}) do
      @protocol.conform(vow.val_vow, [:val_vow | path], via, [k | route], v)
    end

    @spec conform_reducer(@protocol.result, @protocol.result) :: @protocol.result
    defp conform_reducer({:ok, c}, {:ok, cs}), do: {:ok, [c | cs]}
    defp conform_reducer({:error, ps}, {:ok, _}), do: {:error, ps}
    defp conform_reducer({:ok, _}, {:error, ps}), do: {:error, ps}
    defp conform_reducer({:error, ps}, {:error, pblms}), do: {:error, pblms ++ ps}

    @spec size_problems(@for.t, [term], [Vow.Ref.t()], [term], term) :: [
            ConformError.Problem.t()
          ]
    defp size_problems(%{min_length: min}, path, via, route, val)
         when map_size(val) < min do
      pred = wrap(&(map_size(&1) >= min), min: min)
      [ConformError.new_problem(pred, path, via, route, val)]
    end

    defp size_problems(%{max_length: max}, path, via, route, val)
         when not is_nil(max) and map_size(val) > max do
      pred = wrap(&(map_size(&1) <= max), max: max)
      [ConformError.new_problem(pred, path, via, route, val)]
    end

    defp size_problems(_vow, _path, _via, _route, _value) do
      []
    end

    @spec unform_reducer({term, term}, @protocol.result, Vow.t()) :: @protocol.result
    defp unform_reducer(_, {:error, reason}, _vow) do
      {:error, reason}
    end

    defp unform_reducer({key, val}, {:ok, acc}, vow) do
      with {:ok, uv} <- @protocol.unform(vow.val_vow, val),
           {true, _} <- {vow.conform_keys?, uv},
           {:ok, uk} <- @protocol.unform(vow.key_vow, key) do
        {:ok, Map.put(acc, uk, uv)}
      else
        {false, uv} -> {:ok, Map.put(acc, key, uv)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  if Code.ensure_loaded?(StreamData) do
    defimpl Vow.Generatable do
      @moduledoc false

      @impl Vow.Generatable
      def gen(vow, opts) do
        with {:ok, key_gen} <- @protocol.gen(vow.key_vow, opts),
             {:ok, val_gen} <- @protocol.gen(vow.val_vow, opts),
             {opts, _} <- Map.split(Map.from_struct(vow), [:min_length, :max_length]) do
          {:ok,
           StreamData.map_of(
             key_gen,
             val_gen,
             Enum.into(opts, [])
           )}
        else
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end
