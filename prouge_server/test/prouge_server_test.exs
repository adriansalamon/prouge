defmodule ProugeServerTest do
  use ExUnit.Case
  doctest ProugeServer

  test "greets the world" do
    assert ProugeServer.hello() == :world
  end
end
