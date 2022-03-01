defmodule ProugeServer.Client do
  use GenServer, restart: :temporary
  require Logger
  alias ProugeServer.Game, as: Game

  @initial_state %{socket: nil, pid: nil}

  def start_link(socket) do
    Logger.info("Starting Client on socket #{inspect(socket)}")
    GenServer.start_link(__MODULE__, socket)
  end

  def send_game_state(pid, gamestate) do
    GenServer.cast(pid, {:send_game_state, inspect(gamestate)})
  end

  @impl true
  def init(socket) do
    Game.add_player(self())
    {:ok, %{@initial_state | socket: socket, pid: self()}}
  end

  @impl true
  def handle_info({:tcp, socket, message}, state) do
    :inet.setopts(socket, active: :once)
    Logger.info("Revieved packet #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    Logger.info("Closed TCP connection with #{inspect(socket)}")
    Process.exit(self(), :shutdown)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_game_state, gamestate}, %{socket: socket} = state) do
    Logger.info("Sending #{inspect(gamestate)} to #{inspect(state.socket)}")

    :gen_tcp.send(socket, gamestate <> "\n")
    {:noreply, state}
  end
end
