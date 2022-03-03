defmodule ProugeServer.Client do
  require Logger
  use GenServer, restart: :temporary

  @initial_state %{socket: nil, pid: nil}

  def start_link(socket) do
    Logger.info("Staring ProugeServer.Client hell ye")
    GenServer.start_link(__MODULE__, socket)
  end

  def init(socket) do
    {:ok, %{@initial_state | socket: socket, pid: self()}}
  end

  def handle_info({:tcp, socket, message}, state) do
    :inet.setopts(socket, active: :once)
    Logger.info("Recieved message: #{inspect(message)}")
    {:noreply, state}
  end

end
