defmodule ProgeServerTest do
  use ExUnit.Case
  doctest ProgeServer

  test "greets the world" do
    assert ProgeServer.hello() == :world
  end
end
