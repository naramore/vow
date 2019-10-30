defmodule VowTestUtils do
  @moduledoc false

  @type conform_result :: {:ok, conformed :: term} | {:error, Vow.ConformError.t()}

  @spec strip_vow(conform_result) :: conform_result
  def strip_vow({:ok, _} = result), do: result

  def strip_vow({:error, error}) do
    {:error, %{error | vow: nil}}
  end

  @spec strip_via(conform_result) :: conform_result
  def strip_via({:ok, _} = result), do: result

  def strip_via({:error, error}) do
    problems = Enum.map(error.problems, &%{&1 | via: []})
    {:error, %{error | problems: problems}}
  end

  @spec strip_via_and_vow(conform_result) :: conform_result
  def strip_via_and_vow(result) do
    result
    |> strip_via()
    |> strip_vow()
  end

  @spec to_improper([term, ...]) :: maybe_improper_list(term, term) | nil
  def to_improper([]), do: nil
  def to_improper([h | t]), do: [h | to_improper(t)]

  @spec complement(boolean) :: boolean
  def complement(true), do: false
  def complement(false), do: true
end
