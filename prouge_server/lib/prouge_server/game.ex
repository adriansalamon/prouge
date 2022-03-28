defmodule ProugeServer.Game do
  alias ProugeServer.GameMap, as: GameMap
  use GenServer
  require Logger

  defmodule GameState do
    @derive Jason.Encoder
    defstruct players: [], map: %GameMap{}, state: :playing
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
    {:ok, %GameState{map: GameMap.generate_map()}}
  end

  # Add a new player to the game
  @impl true
  def handle_cast({:add_player, pid}, %{players: players, map: %{rooms: rooms}} = state) do
    %{x: x, y: y} = Enum.at(rooms, 0) |> GameMap.Room.center()

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
    for %{pid: pid} <- players do
      ProugeServer.Client.send_state(pid, state)
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:handle_command, pid, %{"command" => %{"move" => direction}}}, _from, %GameState{state: :playing} = state) do
    {:reply, :moved, state |> try_move_players(pid, direction)}
  end

  @impl true
  def handle_call({:handle_command, _, %{"command" => %{"move" => _}}}, _from, state) do
    {:reply, :no_move, state}
  end

  ## Game logic
  defp try_move_players(%GameState{players: players, map: map} = game_state, to_move, direction) do
    newPositions =
      Enum.map(players, fn p ->
        cond do
          p.pid == to_move ->
            new_p =
              case direction do
                "right" -> %{p | x: p.x + 1}
                "left" -> %{p | x: p.x - 1}
                "up" -> %{p | y: p.y - 1}
                "down" -> %{p | y: p.y + 1}
              end

            colliding = GameMap.colliding?(map, players, new_p)
            Logger.debug("colliding: #{inspect(colliding)}")

            case colliding do
              true -> p
              false -> new_p
            end

          true ->
            p
        end
      end)

    {chest_x, chest_y} = ProugeServer.GameMap.get_chest_pos(map)

    has_won =
      Enum.any?(newPositions, fn p ->
        p.x == chest_x && p.y == chest_y
      end)

    state = case has_won do
      true -> :finished
      false -> :playing
    end

    %{game_state | players: newPositions, state: state}
  end
end
