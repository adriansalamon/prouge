defmodule ProugeServer.Game do
  @moduledoc """
  A GenServer process that holds the game state and keeps track/updates the game.
  """
  alias ProugeServer.GameMap
  alias ProugeServer.Game
  use GenServer
  require Logger

  # Gamestate for the whole game
  defmodule GameState do
    @derive {Jason.Encoder, only: [:players, :map, :state, :items]}
    defstruct players: [], map: %GameMap{}, state: :playing, items: []
  end

  # Game items, can be either in a players inventory or on the map
  defmodule Item do
    @derive {Jason.Encoder, only: [:type, :uses]}
    defstruct type: nil, uses: 1

    # Unique id based ItemCounter
    def new(type) do
      uses =
        case type do
          # keys can only be used once
          :key -> 1
          # chest uses is increased for every new player, and decresed when a player unlocks it
          :chest -> 0
        end

      %Item{type: type, uses: uses}
    end

    def change_uses(%Item{uses: n} = item, change_by) do
      %Item{item | uses: n + change_by}
    end
  end

  defmodule Player do
    @derive {Jason.Encoder, only: [:x, :y]}
    defstruct pid: nil, x: 0, y: 0, items: []

    # Returns true if player has a key. A player has a key if any item in inventory is of type key
    def has_key?(%Game.Player{items: items}) do
      Enum.any?(items, fn item -> item.type == :key end)
    end

    # Returns true if a player has a key that has not been used yet
    def has_usable_key?(%Game.Player{items: items}) do
      Enum.any?(items, fn item -> item.type == :key && item.uses >= 1 end)
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: ProugeServer.Game)
  end

  ## Public api
  def add_player(pid) do
    GenServer.cast(__MODULE__, {:add_player, pid})
  end

  def remove_player(pid) do
    GenServer.cast(__MODULE__, {:remove_player, pid})
  end

  # Sends current game-state to all clients
  def send_game_state() do
    GenServer.cast(__MODULE__, {:send_game_state})
  end

  # Handles commands from clients, such as trying to move a player
  def handle_command(player_id, command) do
    GenServer.call(__MODULE__, {:handle_command, player_id, command})
  end

  ## Genserver implementation
  @impl true
  def init(_opts) do
    {:ok, %GameState{map: GameMap.generate_map()}}
  end

  # Add a new player to the game
  @impl true
  def handle_cast({:add_player, pid}, %{players: players, map: %{rooms: rooms} = map} = state) do
    # The new player spawns in middle of first room
    %{x: x, y: y} = Enum.at(rooms, 0) |> GameMap.Room.center()

    # Add a new key at a random room, increment uses of the chest
    map = map |> GameMap.add_item_at_room(:key, Enum.random(2..5)) |> GameMap.increment_chest()

    newState =
      %{state | players: [%Player{pid: pid, x: x, y: y} | players], map: map} |> update_state()

    {:noreply, newState}
  end

  # Remove player with pid
  @impl true
  def handle_cast({:remove_player, pid}, %{players: players} = state) do
    new_players = Enum.filter(players, fn p -> p.pid != pid end)
    {:noreply, %{state | players: new_players}}
  end

  # Send current game state to all players
  @impl true
  def handle_cast({:send_game_state}, %{players: players} = state) do
    for %{pid: pid} <- players do
      ProugeServer.Client.send_state(pid, state)
    end

    {:noreply, state}
  end

  # Handle move commands, when game state is :playing
  @impl true
  def handle_call(
        {:handle_command, player_id, %{"command" => %{"move" => direction}}},
        _from,
        %GameState{state: :playing} = state
      ) do
    # Try to move players and update state
    state = state |> try_move_players(player_id, direction) |> update_state()
    {:reply, :updated, state}
  end

  # If game state is :not_started or :finished, a player cant move
  @impl true
  def handle_call({:handle_command, _, %{"command" => %{"move" => _}}}, _from, state) do
    {:reply, :no_move, state}
  end

  ## Game logic

  # Updates the game state
  defp update_state(state) do
    state
    |> pick_up_items()
    |> check_chest()
    |> discover_rooms()
    |> discover_tunnels()
  end

  # Tries to move all players, takes a gamestate, a player pid to move, and a direction
  defp try_move_players(%GameState{players: players, map: map} = game_state, to_move, direction) do
    newPositions =
      Enum.map(players, fn p ->
        cond do
          p.pid == to_move ->
            # It this player should move
            new_p =
              case direction do
                "right" -> %{p | x: p.x + 1}
                "left" -> %{p | x: p.x - 1}
                "up" -> %{p | y: p.y - 1}
                "down" -> %{p | y: p.y + 1}
              end

            # Check if colliding after moving
            colliding = GameMap.colliding?(map, players, new_p)

            # If colliding return old position, else new
            case colliding do
              true -> p
              false -> new_p
            end

          # Not this player's to move
          true ->
            p
        end
      end)

    %{game_state | players: newPositions}
  end

  # Pick up items from the map
  defp pick_up_items(%GameState{players: players, map: %GameMap{items: items} = gamemap} = state) do
    {players, items} =
      Enum.reduce(players, {players, items}, fn p, {players_acc, items_acc} ->
        case Map.get(items_acc, {p.x, p.y}) do
          %{type: :key} = item ->
            # If there is a key at this item position
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

  # Adds an item to a player inventory
  defp add_item_to_player(players, player_id, item) do
    Enum.map(players, fn p ->
      case p.pid == player_id do
        true -> %{p | items: [item | p.items]}
        false -> p
      end
    end)
  end

  # Logic for handling chest interaction, including winning the game
  defp check_chest(%GameState{players: players, map: %GameMap{items: items} = map} = game_state) do
    {chest_x, chest_y} = ProugeServer.GameMap.get_chest_pos(map)

    # Returns a player trying to unlock a chest, if no one is unlocking, returns :none
    player_unlocking =
      Enum.find(players, :none, fn p ->
        p.x == chest_x && p.y == chest_y && Player.has_usable_key?(p)
      end)

    {items, players} =
      case player_unlocking do
        # If noone is trying to unlock
        :none ->
          {items, players}

        player ->
          # Decrese uses for the chest on the map
          {
            Map.update!(items, {chest_x, chest_y}, &Item.change_uses(&1, -1)),
            # Decrease uses uses for the key in the inventory
            use_key(players, player)
          }
      end

    %{uses: uses} = Map.get(items, {chest_x, chest_y})

    # If uses for chest is 0, game is finished/won
    state =
      cond do
        uses <= 0 -> :finished
        true -> :playing
      end

    %{game_state | state: state, map: %{map | items: items}, players: players}
  end

  # Use a key for player
  defp use_key(players, player) do
    Enum.map(players, fn p ->
      # If player to use key
      if p.pid == player.pid do
        items =
          Enum.map(p.items, fn
            # If key, decrease uses
            %Item{type: :key} = item ->
              Item.change_uses(item, -1)

            other ->
              other
          end)

        %{p | items: items}
      else
        p
      end
    end)
  end

  # Discover rooms, mark room where players are as discovered for each player
  defp discover_rooms(
         %GameState{players: players, map: %GameMap{rooms: rooms} = map} = game_state
       ) do
    rooms =
      Enum.reduce(players, rooms, fn %Player{x: x, y: y, pid: pid}, rooms_acc ->
        # For each player, try to discover the room that the player is in
        GameMap.try_discover_rooms(rooms_acc, x, y, pid)
      end)

    %{game_state | map: %{map | rooms: rooms}}
  end

  # Discover tunnels, mark tunnels where players are as discovered for each player
  defp discover_tunnels(
         %GameState{
           players: players,
           map: %GameMap{h_tunnels: h_tunnels, v_tunnels: v_tunnels} = map
         } = game_state
       ) do
    h_tunnels =
      Enum.reduce(players, h_tunnels, fn %Player{x: x, y: y, pid: pid}, tunnels_acc ->
        GameMap.try_discover_tunnels(tunnels_acc, x, y, pid)
      end)

    v_tunnels =
      Enum.reduce(players, v_tunnels, fn %Player{x: x, y: y, pid: pid}, tunnels_acc ->
        GameMap.try_discover_tunnels(tunnels_acc, x, y, pid)
      end)

    %{game_state | map: %{map | h_tunnels: h_tunnels, v_tunnels: v_tunnels}}
  end
end
