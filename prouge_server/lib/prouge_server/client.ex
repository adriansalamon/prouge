defmodule ProugeServer.Client do
  use GenServer, restart: :temporary
  require Logger
  alias ProugeServer.Game, as: Game

  @initial_state %{socket: nil, pid: nil, user_id: nil}

  def start_link(socket) do
    Logger.info "Starting Client..."
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    :gen_tcp.send(socket, "Please provide user_id: \n")
    {:ok, %{@initial_state | socket: socket, pid: self()}}
  end

  @impl true
  def handle_info({:tcp, socket, message}, %{user_id: nil} = state) do
    :inet.setopts(socket, active: :once)
    id = message |> String.trim() |> String.to_integer()
    Game.add_player(id)
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, socket, message}, state) do
    :inet.setopts(socket, active: :once)
    Logger.info "Revieved packet #{inspect(message)}"
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    Logger.info "Closed TCP connection with #{inspect(socket)}"
    Process.exit(self(), :shutdown)
    {:noreply, state}
  end
end
