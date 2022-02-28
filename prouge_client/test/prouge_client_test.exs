defmodule ProugeClientTest do
  use ExUnit.Case
  doctest ProugeClient

  test "greets the world" do
    assert ProugeClient.hello() == :world
  end
end
