defmodule ProugeServer.Game do
  require Logger
  use GenServer

  ## External API

  def start_link(start_state) do
    GenServer.start_link(__MODULE__, start_state, name: __MODULE__)
  end

  def add_player(player_id) do
    GenServer.cast __MODULE__, {:add_player, player_id}
  end

  def move_player(%{player_id: id, dir: dir}) do
    GenServer.cast __MODULE__, {:move_player, id, dir}
  end

  def get_state() do
    GenServer.call __MODULE__, :get_state
  end

  def set_state(state) do
    GenServer.cast __MODULE__, {:set_state, state}
  end

  defmodule Player do
    defstruct id: 0, x: 0, y: 0
  end

  defmodule State do
    defstruct players: [], clients: []
  end

  ## Genserver implementation
  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:move_player, id, dir}, state) do
    {:noreply, %{state | players: Enum.map(state.players, fn x -> move_player(id, dir, x) end)}}
  end

  @impl true
  def handle_cast({:add_player, id}, state) do
    newPlayer = %Player{id: id}
    {:noreply, Map.update(state, :players, [newPlayer], fn rest -> [ newPlayer | rest ] end)}
  end

  @impl true
  def handle_cast({:set_state, new_state}, _state) do
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end


  defp move_player(player_id, dir, %Player{id: id, x: x, y: y}) do
    cond do
      player_id == id -> case dir do
        :left -> %Player{id: id, x: x-1, y: y}
        :right -> %Player{id: id, x: x+1, y: y}
        :up -> %Player{id: id, x: x, y: y-1}
        :down -> %Player{id: id, x: x, y: y+1}
      end
      true ->  %Player{id: id, x: x, y: y}
    end
  end

end
