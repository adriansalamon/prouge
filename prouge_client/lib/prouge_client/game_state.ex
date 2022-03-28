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
  alias ProugeClient.GameMap.Item
  defstruct x1: 0, x2: 0, y1: 0, y2: 0, items: [%Item{}]
end

defmodule ProugeClient.GameMap do
  alias ProugeClient.GameMap.Room
  alias ProugeClient.GameMap.HTunnel
  alias ProugeClient.GameMap.VTunnel
  defstruct rooms: [%Room{}], h_tunnels: [%HTunnel{}], v_tunnels: [%VTunnel{}], width: 110, height: 30
end

defmodule ProugeClient.Player do
  defstruct x: 0, y: 0
end

defmodule ProugeClient.GameState do
  alias ProugeClient.GameMap
  alias ProugeClient.Player

  defstruct map: %GameMap{}, players: [%Player{}], state: :not_started
end
