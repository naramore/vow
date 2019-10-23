defmodule ExSpecStruct.Foo do
  @moduledoc false
  defstruct [:a, :b, :c]
end

defmodule ExSpecStruct.FooCopy do
  @moduledoc false
  defstruct [:a, :b, :c]
end

defmodule ExSpecStruct.Bar do
  @moduledoc false
  defstruct [:a, :b, :c, :d]
end

defmodule ExSpecStruct.Baz do
  @moduledoc false
  defstruct [:a, :b]
end
