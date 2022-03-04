defmodule ProugeServer.Game do
  use GenServer

  defmodule GameState do
    defstruct players: []
  end

  defmodule Player do
    defstruct pid: nil, x: 0, y: 0
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %GameState{}, name: ProugeServer.Game)
  end

  ## Public api
  def add_player(pid) do
    GenServer.cast(__MODULE__, {:add_player, pid})
  end

  def move_player(pid, direction) do
    GenServer.cast(__MODULE__, {:move_player, pid, direction})
  end

  def remove_all_players() do
    GenServer.cast(__MODULE__, {:remove_all_players})
  end

  ## Genserver implementation
  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:add_player, pid}, %{players: players} = state) do
    newState = %{state | players: [%Player{pid: pid} | players]}
    {:noreply, newState}
  end

  @impl true
  def handle_cast({:move_player, pid, direction}, state) do
    {:noreply, state |> try_move_players(pid, direction)}
  end

  def handle_cast({:remove_all_players}, state) do
    {:noreply, %{state | players: []}}
  end

  ## Game logic
  defp try_move_players(%{players: players} = state, to_move, direction) do
    newPositions =
      Enum.map(players, fn p ->
        cond do
          p.pid == to_move ->
            case direction do
              :right -> %{p | x: p.x + 1}
              :left -> %{p | x: p.x - 1}
              :up -> %{p | y: p.y - 1}
              :down -> %{p | y: p.y + 1}
            end
          true -> p
        end
      end)

    %{state | players: newPositions}
  end
end
