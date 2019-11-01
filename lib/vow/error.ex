defmodule Vow.DuplicateNameError do
  @moduledoc false

  defexception [:vow]

  @type t :: %__MODULE__{
          vow: Vow.t()
        }

  @impl Exception
  def message(%__MODULE__{vow: vow}) do
    "Duplicate sub-vow names are not allowed in #{vow.__struct__}"
  end
end

defmodule Vow.UnnamedVowsError do
  @moduledoc false

  defexception [:vows]

  @type t :: %__MODULE__{
          vows: [Vow.t()]
        }

  @impl Exception
  def message(%__MODULE__{}) do
    "Expected a list of named vows (i.e. [{atom, Vow.t}])."
  end
end

defmodule Vow.DuplicateKeyError do
  @moduledoc false

  defexception duplicates: []

  @type t :: %__MODULE__{
          duplicates: [atom]
        }

  @impl Exception
  def message(%__MODULE__{duplicates: dups}) do
    "Duplicate key names are not allowed: #{inspect(dups)}"
  end
end

defmodule Vow.UnformError do
  @moduledoc false

  defexception [:vow, :value]

  @type t :: %__MODULE__{
          vow: Vow.t(),
          value: Vow.Conformable.conformed()
        }

  @impl Exception
  def message(%__MODULE__{vow: vow, value: value}) do
    "Value, #{value}, was not conformed by vow, #{vow}."
  end
end

defmodule Vow.ConformError do
  @moduledoc false

  defexception problems: [],
               vow: nil,
               value: nil

  @type t :: %__MODULE__{
          problems: [__MODULE__.Problem.t()],
          vow: Vow.t(),
          value: term
        }

  @impl Exception
  def message(%__MODULE__{} = error) do
    Enum.map(error.problems, fn p ->
      __MODULE__.Problem.message(p)
    end)
    |> Enum.join("\n")
  end

  @spec new([__MODULE__.Problem.t()], Vow.t(), term) :: t
  def new(problems, vow, value) do
    %__MODULE__{
      problems: problems,
      vow: vow,
      value: value
    }
  end

  defdelegate new_problem(predicate, vow_path, via, value_path, value, reason \\ nil),
    to: __MODULE__.Problem,
    as: :new

  @spec add_problems(
          {:ok, term} | {:error, [__MODULE__.Problem.t()]},
          [__MODULE__.Problem.t()],
          boolean
        ) ::
          {:ok, term} | {:error, [__MODULE__.Problem.t()]}
  def add_problems(conform_response, problems, add_to_front? \\ false)

  def add_problems(response, [], _add_to_front?),
    do: response

  def add_problems({:ok, _conformed}, [_ | _] = problems, _add_to_front?),
    do: {:error, problems}

  def add_problems({:error, problems}, [_ | _] = more_problems, true),
    do: {:error, more_problems ++ problems}

  def add_problems({:error, problems}, [_ | _] = more_problems, false),
    do: {:error, problems ++ more_problems}

  # coveralls-ignore-start
  defimpl Inspect do
    @moduledoc false

    import Inspect.Algebra

    def inspect(e, opts) do
      coll = [
        {:prob, e.problems},
        {:vow, e.vow},
        {:val, e.value}
      ]

      fun = fn {k, i}, os -> concat([to_string(k), "=", @protocol.inspect(i, os)]) end
      container_doc("#ConformError<", coll, ">", opts, fun, breaK: :strict, separator: ",")
    end
  end

  # coveralls-ignore-stop

  defmodule Problem do
    @moduledoc false

    defstruct predicate: nil,
              vow_path: [],
              via: [],
              value_path: [],
              value: nil,
              reason: nil

    @type t :: %__MODULE__{
            predicate: Vow.t(),
            vow_path: [atom],
            via: [{module, atom}],
            value_path: [term],
            value: term,
            reason: String.t() | nil
          }

    @spec new(Vow.t(), [atom], [module], [term], term, String.t() | nil) :: t
    def new(predicate, vow_path, via, value_path, value, reason \\ nil) do
      %__MODULE__{
        predicate: predicate,
        vow_path: vow_path,
        via: via,
        value_path: value_path,
        value: value,
        reason: reason
      }
    end

    @spec message(t) :: String.t()
    def message(p) do
      if p.value_path == [],
        do: "",
        else:
          "in: #{p.value_path}"
          |> (&"#{&1} value: #{p.value} fails").()
          |> (&if(p.via == [], do: &1, else: "#{&1} vow: #{List.last(p.via)}")).()
          |> (&if(p.vow_path == [], do: &1, else: "#{&1} at: #{p.vow_path}")).()
          |> (&"#{&1} predicate: #{p.predicate}").()
          |> (&if(is_nil(p.reason), do: &1, else: "#{&1} reason: #{p.reason}")).()
    end

    # coveralls-ignore-start
    defimpl Inspect do
      @moduledoc false

      import Inspect.Algebra

      def inspect(problem, opts) do
        coll = [
          {:pred, problem.predicate},
          {:spath, problem.vow_path},
          {:via, problem.via},
          {:vpath, problem.value_path},
          {:value, problem.value},
          {:reason, problem.reason}
        ]

        fun = fn {k, p}, os -> concat([to_string(k), "=", @protocol.inspect(p, os)]) end
        container_doc("#Problem<", coll, ">", opts, fun, break: :flex, separator: ",")
      end
    end

    # coveralls-ignore-stop
  end
end
