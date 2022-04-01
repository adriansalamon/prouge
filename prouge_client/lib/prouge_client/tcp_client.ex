defmodule ProugeClient.TCPClient do
  @moduledoc """
  Process to handle the TCP communication with the game server.
  """
  alias ProugeClient.GameState
  use GenServer
  require Logger

  @initial_state %{socket: nil, app_pid: nil}

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: ProugeClient.TCPClient)
  end

  # Registers the pid of the ratatoullie app so that the tcp process can send messages to it
  def register_app_pid(pid) do
    GenServer.cast(__MODULE__, {:register_app_pid, pid})
  end

  # Connects to the game server
  def connect(addr, port) do
    GenServer.cast(__MODULE__, {:connect, {addr, port}})
  end

  # Sends a coommand to the game server
  def send_command(command) do
    GenServer.cast(__MODULE__, {:send_command, command})
  end

  @impl true
  def init(_state) do
    {:ok, @initial_state}
  end

  @impl true
  def handle_cast({:register_app_pid, pid}, state) do
    {:noreply, %{state | app_pid: pid}}
  end

  @impl true
  def handle_cast({:connect, {addr, port}}, state) do
    # Connect to the game server over tcp, note that packet: n MUST be same on client and server
    {:ok, socket} = :gen_tcp.connect(addr, port, [:binary, packet: 4])
    {:noreply, %{state | socket: socket}}
  end

  @impl true
  def handle_cast({:send_command, command}, %{socket: socket} = state) do
    # Send game command as JSON over TCP to the game server
    :gen_tcp.send(socket, Poison.encode!(%{command: command}))
    {:noreply, state}
  end

  # Recieve tcp game state from the game server
  @impl true
  def handle_info({:tcp, _socket, message}, %{app_pid: pid} = state) do
    # Decode the game game state
    {:ok, decoded} = Poison.decode(message, %{as: %GameState{}, keys: :atoms!})

    # Send an event to the ratatoulle app with a new game state
    send(pid, {:event, {:new_game_state, decoded |> GameState.atomize()}})
    {:noreply, state}
  end

end
