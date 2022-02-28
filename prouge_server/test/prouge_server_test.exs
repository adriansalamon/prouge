defmodule ProugeServerTest do
  use ExUnit.Case
  doctest ProugeServer
  alias ProugeServer.Game, as: Game

  test "greets the world" do
    assert ProugeServer.hello() == :world
  end

  test "should initialize players" do
    Game.set_state(%{players: [%Game.Player{id: 1}, %Game.Player{id: 2}]})
    state = Game.get_state()
    assert state == %{players: [%Game.Player{id: 1}, %Game.Player{id: 2}]}
  end

  test "should move players" do
    :ok = Game.set_state(%{players: [%Game.Player{id: 1}, %Game.Player{id: 2}]})
    Game.move_player(%{player_id: 1, dir: :right})

    assert Game.get_state() == %{players: [%Game.Player{id: 1, x: 1, y: 0}, %Game.Player{id: 2}]}

    Game.move_player(%{player_id: 2, dir: :down})
    assert Game.get_state() == %{players: [%Game.Player{id: 1, x: 1, y: 0}, %Game.Player{id: 2, x: 0, y: 1}]}
  end
end
