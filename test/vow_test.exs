defmodule VowTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData
  doctest Vow

  describe "Vow.conform/2" do
    @tag skip: true
    property "returns" do
      check all spec <- VowData.spec(),
                value <- term() do
        result = Vow.conform(spec, value)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "Vow.also/1" do
  end

  describe "Vow.list_of/2" do
  end

  describe "Vow.map_of/3" do
  end

  describe "Vow.merge/1" do
  end

  describe "Vow.nilable/1" do
  end

  describe "Vow.one_of/1" do
  end
end
