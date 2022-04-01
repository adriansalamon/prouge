defmodule ProugeServer.Client do
  @moduledoc """
  A GenServer process to handle all communication with a single game client.
  """

  require Logger
  use GenServer, restart: :temporary
  alias ProugeServer.Game
  alias ProugeServer.GameMap

  @initial_state %{socket: nil, pid: nil}

  def start_link(socket) do
    Logger.info("Staring ProugeServer.Client over socket #{inspect(socket)}")
    GenServer.start_link(__MODULE__, socket)
  end

  # Sends the gamestate over tcp to a client
  def send_state(pid, game_state) do
    GenServer.cast(pid, {:send_state, game_state})
  end

  @impl true
  def init(socket) do
    # Add as player with current pid as player_id, guaranteed to be unique
    Game.add_player(self())
    # Sends game state to all clients
    Game.send_game_state()
    {:ok, %{@initial_state | socket: socket, pid: self()}}
  end

  # Handles incoming TCP messages/command from client
  @impl true
  def handle_info({:tcp, socket, message}, %{pid: pid} = state) do
    # Allow to recieve more messages
    :inet.setopts(socket, active: :once)
    Logger.debug("Recieved message: #{inspect(message)}, from #{inspect(socket)}")
    {:ok, decoded} = Jason.decode(message)

    # Game logic for hadnling the message/command
    case Game.handle_command(pid, decoded) do
      :moved -> Game.send_game_state()
      _ -> nil
    end

    {:noreply, state}
  end

  # Handles when the TCP connection is closed
  @impl true
  def handle_info({:tcp_closed, socket}, %{pid: pid} = state) do
    Logger.info("Client disconnected, shutting down #{inspect(socket)}")
    # Removes the player
    Game.remove_player(pid)
    Game.send_game_state()
    {:stop, :normal, state}
  end

  # Sends a gamestate to a client
  @impl true
  def handle_cast({:send_state, game_state}, %{socket: socket, pid: player_id} = state) do
    {:ok, encoded} =
      game_state
      |> transform_output(player_id)
      |> Jason.encode()

    Logger.debug("Sending: #{inspect(encoded)} over #{inspect(socket)}")
    :gen_tcp.send(socket, encoded)
    {:noreply, state}
  end

  # Transforms and formats the internal gamestate before encoding to json and sending to clients
  defp transform_output(
         %Game.GameState{map: %{items: items} = map, players: players} = game_state,
         player_id
       ) do
    # Only send the rooms that have been discovered by the player to the client
    discovered_rooms =
      Enum.filter(map.rooms, fn room -> Enum.member?(room.discovered_by, player_id) end)

    # Only send items on the map that are inside rooms that have been discovered by the player
    map_items =
      items
      |> Map.to_list()
      |> Enum.map(fn {{x, y}, item} -> %{x: x, y: y, type: item.type} end)
      |> Enum.filter(fn %{x: x, y: y} -> GameMap.inside_room?(discovered_rooms, x, y) end)

    # Only send the horizontal tunnels that have been discovered by the player to the client
    discovered_h_tunnels =
      Enum.filter(map.h_tunnels, fn t -> Enum.member?(t.discovered_by, player_id) end)

    # Only send the vertical tunnels that have been discovered by the player to the client
    discovered_v_tunnels =
      Enum.filter(map.v_tunnels, fn t -> Enum.member?(t.discovered_by, player_id) end)

    # Get the items that should be in the player inventory
    %{items: player_items} = players |> Enum.find(&(&1.pid == player_id))

    %{
      game_state
      | items: player_items,
        map: %{
          map
          | items: map_items,
            rooms: discovered_rooms,
            h_tunnels: discovered_h_tunnels,
            v_tunnels: discovered_v_tunnels
        }
    }
  end
end
