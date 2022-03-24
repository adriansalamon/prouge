defmodule ProugeServer.Game do
  alias ProugeServer.Map, as: Map
  use GenServer
  require Logger

  defmodule GameState do
    @derive Jason.Encoder
    defstruct players: [], map: %Map{}
  end

  defmodule Player do
    @derive {Jason.Encoder, only: [:x, :y]}
    defstruct pid: nil, x: 0, y: 0
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: ProugeServer.Game)
  end

  ## Public api
  def add_player(pid) do
    GenServer.cast(__MODULE__, {:add_player, pid})
  end

  def remove_all_players() do
    GenServer.cast(__MODULE__, {:remove_all_players})
  end

  def remove_player(pid) do
    GenServer.cast(__MODULE__, {:remove_player, pid})
  end

  # Sends current game-state to all clients
  def send_game_state() do
    GenServer.cast(__MODULE__, {:send_game_state})
  end

  def handle_command(pid, command) do
    GenServer.call(__MODULE__, {:handle_command, pid, command})
  end

  ## Genserver implementation
  @impl true
  def init(_opts) do
    {:ok, %GameState{map: Map.generate_map()}}
  end

  # Add a new player to the game
  @impl true
  def handle_cast({:add_player, pid}, %{players: players, map: %{rooms: rooms}} = state) do

    %{x: x, y: y} = Enum.at(rooms, 0) |> Map.Room.center()

    newState = %{state | players: [%Player{pid: pid, x: x, y: y} | players]}
    {:noreply, newState}
  end

  @impl true
  def handle_cast({:remove_all_players}, state) do
    {:noreply, %{state | players: []}}
  end

  @impl true
  def handle_cast({:remove_player, pid}, %{players: players} = state) do
    new_players = Enum.filter(players, fn p -> p.pid != pid end)
    {:noreply, %{state | players: new_players}}
  end

  @impl true
  def handle_cast({:send_game_state}, %{players: players} = state) do
    for %{pid: pid} <- players do ProugeServer.Client.send_state(pid, state) end
    {:noreply, state}
  end

  @impl true
  def handle_call({:handle_command, pid, %{"command" => %{"move" => direction}}}, _from, state) do
    {:reply, :moved, state |> try_move_players(pid, direction)}
  end

  ## Game logic
  defp try_move_players(%{players: players, map: map} = state, to_move, direction) do
    newPositions =
      Enum.map(players, fn p ->
        cond do
          p.pid == to_move ->
            new_p = case direction do
              "right" -> %{p | x: p.x + 1}
              "left" -> %{p | x: p.x - 1}
              "up" -> %{p | y: p.y - 1}
              "down" -> %{p | y: p.y + 1}
            end
            colliding = Map.colliding?(map, players, new_p)
            Logger.debug("colliding: #{inspect(colliding)}")
            case colliding do
              true -> p
              false -> new_p
            end
          true -> p
        end
      end)

    %{state | players: newPositions}
  end
end
