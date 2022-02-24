defmodule ProgeClientTest do
  use ExUnit.Case
  doctest ProgeClient

  test "greets the world" do
    assert ProgeClient.hello() == :world
  end
end
