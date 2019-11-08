defmodule Vow.WithGen do
  @moduledoc false

  defstruct [:vow, :gen]

  @type t :: %__MODULE__{
          vow: Vow.t(),
          gen: Vow.Generatable.gen_fun()
        }

  @spec new(Vow.t(), Vow.Generatable.gen_fun()) :: t
  def new(vow, gen_fun) do
    %__MODULE__{
      vow: vow,
      gen: gen_fun
    }
  end

  defimpl Vow.Conformable do
    @moduledoc false

    @impl Vow.Conformable
    def conform(%@for{vow: vow}, vow_path, via, value_path, value) do
      @protocol.conform(vow, vow_path, via, value_path, value)
    end

    @impl Vow.Conformable
    def unform(%@for{vow: vow}, value) do
      @protocol.unform(vow, value)
    end
  end

  defimpl Vow.RegexOperator do
    @moduledoc false

    @impl Vow.RegexOperator
    def conform(%@for{vow: vow}, vow_path, via, value_path, value) do
      @protocol.conform(vow, vow_path, via, value_path, value)
    end

    @impl Vow.RegexOperator
    def unform(%@for{vow: vow}, value) do
      @protocol.unform(vow, value)
    end
  end

  defimpl Vow.Generatable do
    @moduledoc false

    @impl Vow.Generatable
    def gen(%@for{gen: gen}, _opts) do
      {:ok, gen.()}
    rescue
      reason -> {:error, reason}
    end
  end

  # coveralls-ignore-start
  defimpl Inspect do
    @moduledoc false

    @impl Inspect
    def inspect(%@for{vow: vow}, opts) do
      @protocol.inspect(vow, opts)
    end
  end

  # coveralls-ignore-stop
end
