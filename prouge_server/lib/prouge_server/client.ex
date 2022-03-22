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
  def handle_cast({:send_state, game_state}, %{socket: socket} = state) do
    :gen_tcp.send(socket, Jason.encode!(game_state))
    {:noreply, state}
  end
end
