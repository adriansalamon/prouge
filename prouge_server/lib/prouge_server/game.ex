defmodule ProugeServer.Game do
  alias ProugeServer.GameMap
  alias ProugeServer.Game
  use GenServer
  require Logger

  defmodule GameState do
    @derive {Jason.Encoder, only: [:players, :map, :state, :items]}
    defstruct players: [], map: %GameMap{}, state: :playing, items: []
  end

  defmodule Item do
    @derive {Jason.Encoder, only: [:type]}
    defstruct id: nil, type: nil, uses: 1

    def new(type) do
      id = Game.ItemCounter.get()
      :ok = Game.ItemCounter.inc()

      uses =
        case type do
          :key -> 1
          :chest -> 0
        end

      %Item{type: type, id: id, uses: uses}
    end

    def change_uses(%Item{uses: n} = item, change_by) do
      %Item{item | uses: n + change_by}
    end
  end

  defmodule Player do
    @derive {Jason.Encoder, only: [:x, :y]}
    defstruct pid: nil, x: 0, y: 0, items: []

    def has_key?(%Game.Player{items: items}) do
      Enum.any?(items, fn item -> item.type == :key end)
    end

    def has_usable_key?(%Game.Player{items: items}) do
      Enum.any?(items, fn item -> item.type == :key && item.uses >= 1 end)
    end
  end

  defmodule ItemCounter do
    use Agent

    def start_link(_args) do
      Agent.start_link(fn -> 0 end, name: __MODULE__)
    end

    def get do
      Agent.get(__MODULE__, & &1)
    end

    def inc do
      Agent.update(__MODULE__, &(&1 + 1))
    end
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
  def handle_cast({:add_player, pid}, %{players: players, map: %{rooms: rooms} = map} = state) do
    %{x: x, y: y} = Enum.at(rooms, 0) |> GameMap.Room.center()

    map = map |> GameMap.add_item_at_room(:key, Enum.random(2..5)) |> GameMap.increment_chest()
    newState = %{state | players: [%Player{pid: pid, x: x, y: y} | players], map: map}
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
  def handle_call(
        {:handle_command, pid, %{"command" => %{"move" => direction}}},
        _from,
        %GameState{state: :playing} = state
      ) do
    {:reply, :moved, state |> try_move_players(pid, direction) |> update_state()}
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

    %{game_state | players: newPositions}
  end

  defp update_state(state) do
    state
    |> pick_up_items()
    |> check_chest()
  end

  defp pick_up_items(%GameState{players: players, map: %GameMap{items: items} = gamemap} = state) do
    {players, items} =
      Enum.reduce(players, {players, items}, fn p, {players_acc, items_acc} ->
        case Map.get(items_acc, {p.x, p.y}) do
          %{type: :key} = item ->
            case Player.has_key?(p) do
              # Player already has a key in inventory
              true ->
                {players_acc, items_acc}

              # Otherwise, remove from map and add to inventory
              false ->
                {add_item_to_player(players_acc, p.pid, item), Map.delete(items_acc, {p.x, p.y})}
            end

          _ ->
            {players_acc, items_acc}
        end
      end)

    %GameState{state | players: players, map: %GameMap{gamemap | items: items}}
  end

  defp add_item_to_player(players, pid, item) do
    Enum.map(players, fn p ->
      case p.pid == pid do
        true -> %{p | items: [item | p.items]}
        false -> p
      end
    end)
  end

  defp check_chest(%GameState{players: players, map: %GameMap{items: items} = map} = game_state) do
    {chest_x, chest_y} = ProugeServer.GameMap.get_chest_pos(map)

    player_unlocking =
      Enum.find(players, :none, fn p ->
        p.x == chest_x && p.y == chest_y && Player.has_usable_key?(p)
      end)

    {items, players} =
      case player_unlocking do
        :none ->
          {items, players}

        player ->
          {Map.update!(items, {chest_x, chest_y}, &Item.change_uses(&1, -1)),
           Enum.map(players, fn p ->
             case p.pid == player.pid do
               true ->
                 %{
                   p
                   | items:
                       Enum.map(p.items, fn
                         %Item{type: :key} = item ->
                           Item.change_uses(item, -1)

                         other ->
                           other
                       end)
                 }

               false ->
                 p
             end
           end)}
      end

    %{uses: uses} = Map.get(items, {chest_x, chest_y})

    state =
      cond do
        uses <= 0 -> :finished
        true -> :playing
      end

    %{game_state | state: state, map: %{map | items: items}, players: players}
  end
end
