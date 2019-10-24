defmodule Vow.Function do
  @moduledoc """
  TODO
  """

  alias Vow.ConformError

  defstruct [:args, :ret, :fun]

  @type t :: %__MODULE__{
          args: [Vow.t()] | nil,
          ret: Vow.t() | nil,
          fun: Vow.t() | nil
        }

  @doc false
  @spec new([Vow.t()] | nil, Vow.t() | nil, Vow.t() | nil) :: t
  def new(args, ret, fun) do
    %__MODULE__{
      args: args,
      ret: ret,
      fun: fun
    }
  end

  @type fun_value :: %{args: [term], ret: term}

  @doc false
  @spec fun_value(conformed_args :: [term], conformed_ret :: term) :: fun_value
  def fun_value(conformed_args, conformed_ret) do
    %{
      args: conformed_args,
      ret: conformed_ret
    }
  end

  @type f :: (... -> any) | mfa | {module, atom}
  @type conformed_function :: %{
          args: [conformed_arg :: term] | nil,
          ret: conformed_ret :: term | nil,
          fun:
            %{
              args: [conformed_arg :: term],
              ret: conformed_ret :: term
            }
            | nil
        }

  @doc """
  """
  @spec conform(t, f, args :: [term]) ::
          {:ok, conformed_function}
          | {:error, {:args | :ret | :fun, [ConformError.Problem.t()]}}
  def conform(spec, fun, args \\ []) do
    with {:aspec, aspec} when not is_nil(aspec) <- {:aspec, spec.args},
         {:cargs, {:ok, cargs}} <- {:cargs, Vow.conform(aspec, args)},
         {:ret, ret} <- {:ret, execute!(fun, args)},
         {:rspec, rspec, _} when not is_nil(rspec) <- {:rspec, spec.ret, cargs},
         {:cret, {:ok, cret}} <- {:cret, Vow.conform(rspec, ret)},
         {:fval, fval} <- {:fval, %{args: cargs, ret: cret}},
         {:fspec, fspec, _, _} when not is_nil(fspec) <- {:fspec, spec.fun, cargs, cret},
         {:cfun, {:ok, cfun}} <- {:cfun, Vow.conform(fspec, fval)} do
      {:ok, Map.put(fval, :fun, cfun)}
    else
      {:cargs, {:error, ps}} ->
        {:error, {:args, ps}}

      {:rspec, nil, cargs} ->
        {:ok, %{args: cargs, ret: nil, fun: nil}}

      {:cret, {:error, ps}} ->
        {:error, {:ret, ps}}

      {:fspec, nil, cargs, cret} ->
        {:ok, %{args: cargs, ret: cret, fun: nil}}

      {:cfun, {:error, ps}} ->
        {:error, {:fun, ps}}

      {:aspec, nil} ->
        with {:rspec, rspec} when not is_nil(rspec) <- {:rspec, spec.ret},
             {:ret, ret} <- {:ret, execute!(fun, args)},
             {:cret, {:ok, cret}} <- {:cret, Vow.conform(rspec, ret)} do
          %{args: nil, ret: cret, fun: nil}
        else
          {:rspec, nil} -> {:ok, %{args: nil, ret: nil, fun: nil}}
          {:cret, {:error, ps}} -> {:error, {:ret, ps}}
        end
    end
  end

  @spec execute!(f, args :: [term]) :: term
  defp execute!({m, f, _}, args), do: execute!({m, f}, args)
  defp execute!({m, f}, args), do: apply(m, f, args)
  defp execute!(fun, args) when is_function(fun), do: fun.(args)
end
