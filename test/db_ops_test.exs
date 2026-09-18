defmodule DbOpsTest do
  use ExUnit.Case
  doctest DbOps

  test "greets the world" do
    assert DbOps.hello() == :world
  end
end
