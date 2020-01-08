defmodule Vow.Function do
  @moduledoc """
  This module contains utilities for conforming the arguments and return
  values of functions.
  """

  alias Vow.ConformError

  @typedoc """
  The options for `Vow.conform_function/1`.

  * `:args` - a vow for the function arguments as they were a list to be passed to `apply/2` (optional)
  * `:ret` - a vow for the function's return value (optional)
  * `:fun` - a vow of the relationship between `:args` and `:ret`, the value
  passed is `%{args: [conformed_arg], ret: conformed_ret}`
  """
  @type conform_opts :: [
          {:args, [Vow.t()]}
          | {:ret, Vow.t()}
          | {:fun, Vow.t()}
        ]

  @type f :: (... -> any) | mfa | {module, atom}

  @doc """
  Conforms the execution of function `fun`, given arguments `args`,
  via the `conform_opts`.

  This will validate that all arguments conform to the `:args` vows in
  `conform_opts` prior to function execution, and that the return value
  conforms to the `:ret` vow in `conform_opts`.

  Both the `:args` and `:ret` options are required for the `:fun` option.
  """
  @spec conform(f, args :: [term], conform_opts) ::
          {:ok, {term, %{args: term, ret: term, fun: term}}}
          | {:error, {:args | :ret | :fun, ConformError.t()} | {:execute, reason :: term}}
  def conform(fun, args, opts) do
    with {:args, {:ok, conformed_args}} <- {:args, conform_args(args, opts)},
         {:execute, {:ok, ret}} <- {:execute, execute(fun, args)},
         {:ret, {:ok, conformed_ret}} <- {:ret, conform_ret(ret, opts)},
         {:fun, {:ok, conformed_fun}} <- {:fun, conform_fun(conformed_args, conformed_ret, opts)} do
      conformed = %{args: conformed_args, ret: conformed_ret, fun: conformed_fun}
      {:ok, {ret, conformed}}
    else
      {op, {:error, problems}} -> {:error, {op, problems}}
    end
  end

  @spec conform_args(args :: [term], conform_opts) ::
          {:ok, [term] | nil} | {:error, ConformError.t()}
  defp conform_args(args, opts) do
    if Keyword.has_key?(opts, :args) do
      Vow.conform(Keyword.get(opts, :args), args)
    else
      {:ok, nil}
    end
  end

  @spec conform_ret(ret :: term, conform_opts) ::
          {:ok, term | nil} | {:error, ConformError.t()}
  defp conform_ret(ret, opts) do
    if Keyword.has_key?(opts, :ret) do
      Vow.conform(Keyword.get(opts, :ret), ret)
    else
      {:ok, nil}
    end
  end

  @spec conform_fun(conformed_args :: term, conformed_ret :: term, conform_opts) ::
          {:ok, term | nil} | {:error, ConformError.t()}
  defp conform_fun(conformed_args, conformed_ret, opts) do
    if has_all_keys?(opts, [:args, :ret, :fun]) do
      Vow.conform(
        Keyword.get(opts, :fun),
        %{args: conformed_args, ret: conformed_ret}
      )
    else
      {:ok, nil}
    end
  end

  @spec has_all_keys?(keyword, [atom]) :: boolean
  defp has_all_keys?(keyword, keys) do
    Enum.all?(keys, &Keyword.has_key?(keyword, &1))
  end

  @spec execute(f, args :: [term]) :: {:ok, result :: term} | {:error, reason :: term}
  defp execute(fun, args) do
    {:ok, execute!(fun, args)}
  rescue
    reason -> {:error, reason}
  catch
    caught -> {:error, caught}
  end

  @spec execute!(f, args :: [term]) :: term
  defp execute!({m, f, _}, args), do: execute!({m, f}, args)
  defp execute!({m, f}, args), do: apply(m, f, args)
  defp execute!(fun, args) when is_function(fun), do: fun.(args)
end
