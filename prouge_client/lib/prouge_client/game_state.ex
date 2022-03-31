defmodule ProugeClient.GameMap.HTunnel do
  defstruct x1: 0, x2: 0, y: 0
end

defmodule ProugeClient.GameMap.VTunnel do
  defstruct x: 0, y1: 0, y2: 0
end

defmodule ProugeClient.GameMap.Item do
  defstruct x: 0, y: 0, type: nil
end

defmodule ProugeClient.GameMap.Room do
  defstruct x1: 0, x2: 0, y1: 0, y2: 0
end

defmodule ProugeClient.GameMap.Item do
  defstruct x: 0, y: 0, type: nil
end

defmodule ProugeClient.GameMap do
  alias ProugeClient.GameMap.Room
  alias ProugeClient.GameMap.HTunnel
  alias ProugeClient.GameMap.VTunnel
  alias ProugeClient.GameMap.Item
  defstruct rooms: [%Room{}], h_tunnels: [%HTunnel{}], v_tunnels: [%VTunnel{}], items: [%Item{}], width: 110, height: 30
end

defmodule ProugeClient.Player do
  defstruct x: 0, y: 0
end

defmodule ProugeClient.Item do
  defstruct type: nil
end

defmodule ProugeClient.GameState do
  alias ProugeClient.GameState
  alias ProugeClient.GameMap
  alias ProugeClient.Player
  alias ProugeClient.Item

  @states [:not_started, :playing, :finished]
  @item_types [:chest, :key]

  defstruct map: %GameMap{}, players: [%Player{}], state: :not_started, items: [%Item{}]

  def atomize(%GameState{items: player_items, map: %GameMap{items: map_items} = game_map, state: state} = game_state) do
    state = case state do
      state when is_atom(state)-> state
      state -> String.to_existing_atom(state)
    end
    state = case Enum.member?(@states, state) do
      true -> state
      false -> raise ArgumentError, "State not valid"
    end

    updated_player_items = Enum.map(player_items, fn %{type: type} = item ->
      type = String.to_existing_atom(type)
      case Enum.member?(@item_types, type) do
        true -> %{item | type: type}
        false -> raise ArgumentError, "Item not valid"
      end
    end)

    updated_map_items = Enum.map(map_items, fn  %{type: type} = item ->
      type = String.to_existing_atom(type)
      case Enum.member?(@item_types, type) do
        true -> %{item | type: type}
        false -> raise ArgumentError, "Item not valid"
      end
    end)

    %{game_state | state: state, items: updated_player_items, map: %GameMap{game_map | items: updated_map_items}}
  end
end
