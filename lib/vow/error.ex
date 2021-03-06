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

  defexception [:vow, :val]

  @type t :: %__MODULE__{
          vow: Vow.t(),
          val: Vow.Conformable.conformed()
        }

  @impl Exception
  def message(%__MODULE__{vow: vow, val: val}) do
    "Value, #{val}, was not conformed by vow, #{vow}."
  end
end

defmodule Vow.ResolveError do
  @moduledoc false

  defexception [:pred, :reason, :ref]

  @type t :: %__MODULE__{
          pred: Vow.t() | nil,
          reason: String.t() | nil,
          ref: Vow.Ref.t()
        }

  @impl Exception
  def message(%__MODULE__{ref: ref, reason: nil, pred: pred})
      when not is_nil(pred) do
    "#{ref} failed predicate #{pred}"
  end

  def message(%__MODULE__{ref: ref, reason: reason, pred: nil})
      when not is_nil(reason) do
    "#{ref} failed with reason #{reason}"
  end

  def message(%__MODULE__{ref: ref, reason: reason, pred: pred}) do
    "#{ref} failed predicate #{pred} with reason #{reason}"
  end

  @spec new(Vow.Ref.t(), Vow.t() | nil, String.t() | nil) :: t
  def new(ref, pred, reason \\ nil) do
    %__MODULE__{
      pred: pred,
      reason: reason,
      ref: ref
    }
  end
end

defmodule Vow.ConformError do
  @moduledoc false

  defexception problems: [],
               vow: nil,
               val: nil

  @type t :: %__MODULE__{
          problems: [__MODULE__.Problem.t()],
          vow: Vow.t(),
          val: term
        }

  @impl Exception
  def message(%__MODULE__{} = error) do
    error.problems
    |> Enum.map(fn p ->
      __MODULE__.Problem.message(p)
    end)
    |> Enum.join("\n")
  end

  @spec new([__MODULE__.Problem.t()], Vow.t(), term) :: t
  def new(problems, vow, val) do
    %__MODULE__{
      problems: problems,
      vow: vow,
      val: val
    }
  end

  defdelegate new_problem(pred, path, via, route, val, reason \\ nil),
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
        {:val, e.val}
      ]

      fun = fn {k, i}, os -> concat([to_string(k), "=", @protocol.inspect(i, os)]) end
      container_doc("#ConformError<", coll, ">", opts, fun, breaK: :strict, separator: ",")
    end
  end

  # coveralls-ignore-stop

  defmodule Problem do
    @moduledoc false

    defstruct pred: nil,
              path: [],
              via: [],
              route: [],
              val: nil,
              reason: nil

    @type t :: %__MODULE__{
            pred: Vow.t() | nil,
            path: [term],
            via: [Vow.Ref.t()],
            route: [term],
            val: term,
            reason: String.t() | nil
          }

    @spec new(Vow.t(), [term], [Vow.Ref.t()], [term], term, String.t() | nil) :: t
    def new(pred, path, via, route, val, reason \\ nil) do
      %__MODULE__{
        pred: pred,
        path: :lists.reverse(path),
        via: :lists.reverse(via),
        route: :lists.reverse(route),
        val: val,
        reason: reason
      }
    end

    @spec message(t) :: String.t()
    def message(p) do
      p.route
      |> (&if(&1 == [], do: "", else: "in: #{inspect(&1)}")).()
      |> (&"#{&1} val: #{inspect(p.val)} fails").()
      |> (&if(p.via == [], do: &1, else: "#{&1} vow: #{List.last(p.via)}")).()
      |> (&if(p.path == [], do: &1, else: "#{&1} at: #{inspect(p.path)}")).()
      |> (&"#{&1} pred: #{inspect(p.pred)}").()
      |> (&if(is_nil(p.reason), do: &1, else: "#{&1} reason: #{p.reason}")).()
    end

    @spec from_resolve_error(Vow.ResolveError.t(), [term], [Vow.Ref.t()], [term], term) :: t
    def from_resolve_error(resolve_error, path, via, route, val) do
      new(
        resolve_error.pred,
        path,
        [resolve_error.ref | via],
        route,
        val,
        resolve_error.reason
      )
    end

    # coveralls-ignore-start
    defimpl Inspect do
      @moduledoc false

      import Inspect.Algebra

      @impl Inspect
      def inspect(problem, opts) do
        coll = [
          {:pred, problem.pred},
          {:path, problem.path},
          {:via, problem.via},
          {:route, problem.route},
          {:val, problem.val},
          {:reason, problem.reason}
        ]

        fun = fn {k, p}, os -> concat([to_string(k), "=", @protocol.inspect(p, os)]) end
        container_doc("#Problem<", coll, ">", opts, fun, break: :flex, separator: ",")
      end
    end

    # coveralls-ignore-stop
  end
end
