defmodule ProugeServerTest do
  use ExUnit.Case
  doctest ProugeServer
  alias ProugeServer.Game, as: Game

  test "greets the world" do
    assert ProugeServer.hello() == :world
  end

  setup do
    pid1 = spawn(fn -> nil end)
    pid2 = spawn(fn -> nil end)

    Game.set_state(%{})
    Game.add_player(pid2)
    Game.add_player(pid1)

    {:ok, pids: [pid1, pid2]}
  end

  test "should initialize players", context do
    state = Game.get_state()
    assert state == %{players: Enum.map(context[:pids], fn x -> %Game.Player{pid: x} end)}
  end

  test "should move players", context do
    Game.move_player(Enum.at(context[:pids], 0), :right)

    assert Game.get_state() == %{
             players: [
               %Game.Player{pid: Enum.at(context[:pids], 0), x: 1, y: 0},
               %Game.Player{pid: Enum.at(context[:pids], 1), x: 0, y: 0}
             ]
           }

    Game.move_player(Enum.at(context[:pids], 1), :down)

    assert Game.get_state() == %{
             players: [
               %Game.Player{pid: Enum.at(context[:pids], 0), x: 1, y: 0},
               %Game.Player{pid: Enum.at(context[:pids], 1), x: 0, y: 1}
             ]
           }
  end
end
