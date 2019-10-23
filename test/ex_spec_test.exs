defmodule ExSpecTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  doctest ExSpec

  describe "ExSpec.conform/2" do
    @tag skip: true
    property "returns" do
      check all spec <- ExSpecData.spec(),
                value <- term() do
        result = ExSpec.conform(spec, value)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "ExSpec.also/1" do
  end

  describe "ExSpec.list_of/2" do
  end

  describe "ExSpec.map_of/3" do
  end

  describe "ExSpec.merge/1" do
  end

  describe "ExSpec.nilable/1" do
  end

  describe "ExSpec.one_of/1" do
  end
end
