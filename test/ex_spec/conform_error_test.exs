defmodule ExSpec.ConformErrorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  doctest ExSpec.ConformError

  describe "ConformError.Problem" do
    property "should navigate spec successfully" do
    end

    property "should naviate value successfully to problem.value" do
    end
  end
end
