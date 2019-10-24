defmodule VowStruct.Foo do
  @moduledoc false
  defstruct [:a, :b, :c]
end

defmodule VowStruct.FooCopy do
  @moduledoc false
  defstruct [:a, :b, :c]
end

defmodule VowStruct.Bar do
  @moduledoc false
  defstruct [:a, :b, :c, :d]
end

defmodule VowStruct.Baz do
  @moduledoc false
  defstruct [:a, :b]
end
