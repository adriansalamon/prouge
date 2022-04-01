defmodule ProugeServer.Client do
  require Logger
  use GenServer, restart: :temporary
  alias ProugeServer.Game, as: Game

  @initial_state %{socket: nil, pid: nil}

  def start_link(socket) do
    Logger.info("Staring ProugeServer.Client hell ye")
    GenServer.start_link(__MODULE__, socket)
  end

  def send_state(pid, game_state) do
    GenServer.cast(pid, {:send_state, game_state})
  end

  @impl true
  def init(socket) do
    # Add as player
    Game.add_player(self())
    Game.send_game_state()
    {:ok, %{@initial_state | socket: socket, pid: self()}}
  end

  @impl true
  def handle_info({:tcp, socket, message}, %{pid: pid} = state) do
    :inet.setopts(socket, active: :once)
    Logger.debug("Recieved message: #{inspect(message)}, from #{inspect(socket)}")
    {:ok, decoded} = Jason.decode(message)

    case Game.handle_command(pid, decoded) do
      :moved -> Game.send_game_state()
      _ -> nil
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, %{pid: pid} = state) do
    Logger.info("Client disconnected, shutting down #{inspect(socket)}")
    Game.remove_player(pid)
    Game.send_game_state()
    {:stop, :normal, state}
  end

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

  defp transform_output(
         %Game.GameState{map: %{items: items} = map, players: players} = game_state,
         player_id
       ) do
    map_items =
      items |> Map.to_list() |> Enum.map(fn {{x, y}, item} -> %{x: x, y: y, type: item.type} end)

    discovered_rooms =
      Enum.filter(map.rooms, fn room -> Enum.member?(room.discovered_by, player_id) end)

    discovered_h_tunnels =
      Enum.filter(map.h_tunnels, fn t -> Enum.member?(t.discovered_by, player_id) end)

    discovered_v_tunnels =
      Enum.filter(map.v_tunnels, fn t -> Enum.member?(t.discovered_by, player_id) end)

    %{items: player_items} = players |> Enum.find(&(&1.pid == player_id))

    %{game_state | map: %{map | items: map_items, rooms: discovered_rooms, h_tunnels: discovered_h_tunnels, v_tunnels: discovered_v_tunnels}, items: player_items}
  end
end
