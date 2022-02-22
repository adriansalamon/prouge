defmodule ProugeTest do
  use ExUnit.Case
  doctest Prouge

  test "greets the world" do
    assert Prouge.hello() == :world
  end
end
