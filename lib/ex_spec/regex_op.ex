defmodule ExSpec.RegexOp do
  @moduledoc false

  @spec init_path([term]) :: [term]
  def init_path(path) do
    path ++ [0]
  end

  @spec uninit_path([term]) :: [term]
  def uninit_path(path) do
    List.delete_at(path, length(path) - 1)
  end

  @spec inc_path([term]) :: [term]
  def inc_path(path) do
    List.update_at(path, length(path) - 1, fn i -> i + 1 end)
  end
end
