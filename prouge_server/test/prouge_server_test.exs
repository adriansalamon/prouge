defmodule ProugeServerTest do
  use ExUnit.Case
  doctest ProugeServer
  alias ProugeServer.Game, as: Game
  alias ProugeServer.Game.Player, as: Player
  alias ProugeServer.Game.GameState, as: GameState


  test "add players work" do
    Game.remove_all_players()
    Game.add_player(self())

    expected = %GameState{players: [%Player{pid: self()}]}

    state = :sys.get_state(ProugeServer.Game)
    assert state.players == expected.players
  end

  test "move players work" do
    Game.remove_all_players()
    pid1 = :c.pid(0,255,0)
    pid2 = :c.pid(0,254,0)

    Game.add_player(pid1)
    Game.add_player(pid2)

    Game.handle_command(pid1, %{"command" => %{"move" => "right"}})
    Game.handle_command(pid2, %{"command" => %{"move" => "down"}})

    expected = %GameState{players: [%Player{pid: pid2, x: 0, y: 1}, %Player{pid: pid1, x: 1, y: 0}]}

    state = :sys.get_state(ProugeServer.Game)
    assert state.players == expected.players
  end
end
