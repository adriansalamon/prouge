defmodule ProugeServer.Game do
  require Logger
  use GenServer

  ## External API

  def start_link(start_state) do
    GenServer.start_link(__MODULE__, start_state, name: __MODULE__)
  end

  def add_player(pid) do
    GenServer.cast __MODULE__, {:add_player, pid}
  end

  def move_player(pid, dir) do
    GenServer.cast __MODULE__, {:move_player, pid, dir}
  end

  def get_state() do
    GenServer.call __MODULE__, :get_state
  end

  def set_state(state) do
    GenServer.cast __MODULE__, {:set_state, state}
  end

  defmodule Player do
    defstruct pid: 0, x: 0, y: 0
  end

  defmodule State do
    defstruct players: []
  end

  ## Genserver implementation
  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:move_player, pid, dir}, state) do
    {:noreply, %{state | players: Enum.map(state.players, fn x -> move_player(pid, dir, x) end)}}
  end

  @impl true
  def handle_cast({:add_player, pid}, state) do
    newPlayer = %Player{pid: pid}
    state = Map.update(state, :players, [newPlayer], fn rest -> [ newPlayer | rest ] end)
    for player <- state.players do ProugeServer.Client.send_game_state(player.pid, state) end
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_state, new_state}, _state) do
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end


  defp move_player(pid_to_move, dir, %Player{pid: pid, x: x, y: y} = player) do
    cond do
      pid_to_move == pid -> case dir do
        :left -> %Player{ player | x: x-1}
        :right -> %Player{ player | x: x+1}
        :up -> %Player{ player | y: y-1}
        :down -> %Player{ player | y: y+1}
      end
      true ->  player
    end
  end

end
