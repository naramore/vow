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

  @doc """
  """
  @spec new([Vow.t()] | nil, Vow.t() | nil, Vow.t() | nil) :: t
  def new(args, ret, fun) do
    %__MODULE__{
      args: args,
      ret: ret,
      fun: fun
    }
  end

  @typedoc """
  """
  @type fun_value :: %{args: [term], ret: term}

  @doc """
  """
  @spec fun_value(conformed_args :: [term], conformed_ret :: term) :: fun_value
  def fun_value(conformed_args, conformed_ret) do
    %{
      args: conformed_args,
      ret: conformed_ret
    }
  end

  @typedoc """
  """
  @type f :: (... -> any) | mfa | {module, atom}

  @typedoc """
  """
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
  def conform(vow, fun, args \\ []) do
    with {:avow, avow} when not is_nil(avow) <- {:avow, vow.args},
         {:cargs, {:ok, cargs}} <- {:cargs, Vow.conform(avow, args)},
         {:ret, ret} <- {:ret, execute!(fun, args)},
         {:rvow, rvow, _} when not is_nil(rvow) <- {:rvow, vow.ret, cargs},
         {:cret, {:ok, cret}} <- {:cret, Vow.conform(rvow, ret)},
         {:fval, fval} <- {:fval, %{args: cargs, ret: cret}},
         {:fvow, fvow, _, _} when not is_nil(fvow) <- {:fvow, vow.fun, cargs, cret},
         {:cfun, {:ok, cfun}} <- {:cfun, Vow.conform(fvow, fval)} do
      {:ok, Map.put(fval, :fun, cfun)}
    else
      {:cargs, {:error, ps}} ->
        {:error, {:args, ps}}

      {:rvow, nil, cargs} ->
        {:ok, %{args: cargs, ret: nil, fun: nil}}

      {:cret, {:error, ps}} ->
        {:error, {:ret, ps}}

      {:fvow, nil, cargs, cret} ->
        {:ok, %{args: cargs, ret: cret, fun: nil}}

      {:cfun, {:error, ps}} ->
        {:error, {:fun, ps}}

      {:avow, nil} ->
        with {:rvow, rvow} when not is_nil(rvow) <- {:rvow, vow.ret},
             {:ret, ret} <- {:ret, execute!(fun, args)},
             {:cret, {:ok, cret}} <- {:cret, Vow.conform(rvow, ret)} do
          %{args: nil, ret: cret, fun: nil}
        else
          {:rvow, nil} -> {:ok, %{args: nil, ret: nil, fun: nil}}
          {:cret, {:error, ps}} -> {:error, {:ret, ps}}
        end
    end
  end

  @spec execute!(f, args :: [term]) :: term
  defp execute!({m, f, _}, args), do: execute!({m, f}, args)
  defp execute!({m, f}, args), do: apply(m, f, args)
  defp execute!(fun, args) when is_function(fun), do: fun.(args)
end
