defmodule ProugeClient.TCPClient do
  alias ProugeClient.GameState
  use GenServer
  require Logger

  @initial_state %{socket: nil, client_pid: nil}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: ProugeClient.TCPClient)
  end

  def init(_state) do
    {:ok, @initial_state}
  end

  def set_client(pid) do
    GenServer.cast(__MODULE__, {:set_client_pid, pid})
  end

  def connect(addr, port) do
    GenServer.cast(__MODULE__, {:connect, {addr, port}})
  end

  def send_command(command) do
    GenServer.cast(__MODULE__, {:send_command, command})
  end


  @impl true
  def handle_cast({:connect, {addr, port}}, state) do
    {:ok, socket} = :gen_tcp.connect(addr, port, [:binary, packet: 4])
    {:noreply, %{state | socket: socket}}
  end

  @impl true
  def handle_cast({:set_client_pid, pid}, state) do
    {:noreply, %{state | client_pid: pid}}
  end

  @impl true
  def handle_cast({:send_command, command}, %{socket: socket} = state) do
    :gen_tcp.send(socket, Poison.encode!(%{command: command}))
    {:noreply, state}
  end

  # Recieve tcp game state
  @impl true
  def handle_info({:tcp, _socket, message}, %{client_pid: pid} = state) do
    {:ok, decoded} = Poison.decode(message, %{as: %GameState{}, keys: :atoms!})
    send(pid, {:event, {:new_game_state, decoded}})
    {:noreply, state}
  end

end
