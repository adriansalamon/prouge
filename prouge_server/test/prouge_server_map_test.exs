defmodule ProugeServerMapTest do
  alias ProugeServer.Map, as: Map
  alias ProugeServer.Map.Room, as: Room
  use ExUnit.Case

  test "create room works" do
    room = Room.new(2, 4, 4, 5)
    assert room == %Room{x1: 2, y1: 4, x2: 6, y2: 9}
  end

  test "add room to map works" do
    room = Room.new(2, 4, 4, 5)

    map = Map.add_room(%Map{}, room)

    assert map == %Map{rooms: [%Room{x1: 2, y1: 4, x2: 6, y2: 9}]}
  end
end
