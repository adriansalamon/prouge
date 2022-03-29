defmodule ProugeServer.GameMap do
  alias ProugeServer.GameMap
  alias ProugeServer.Game
  alias ProugeServer.Game.Player
  alias ProugeServer.BSP
  @derive Jason.Encoder

  @depth 5
  @width 110
  @height 30

  defstruct rooms: [], h_tunnels: [], v_tunnels: [], items: %{}, width: @width, height: @height

  # Item on the map
  defmodule MapItem do
    alias GameMap.MapItem
    alias ProugeServer.Game.Item
    @derive Jason.Encoder
    defstruct x: 0, y: 0, item: nil

    def new(x, y, %Item{} = item) do
      %MapItem{x: x, y: y, item: item}
    end
  end

  # A room to be displayed
  defmodule Room do
    @derive Jason.Encoder
    defstruct x1: 0, x2: 0, y1: 0, y2: 0

    def new(x, y, w, h) do
      %Room{x1: x, y1: y, x2: x + w, y2: y + h}
    end

    # Returns the center of a room
    def center(%Room{} = room) do
      center_x = div(room.x1 + room.x2, 2)
      center_y = div(room.y1 + room.y2, 2)
      %{x: center_x, y: center_y}
    end
  end

  # A horizontal tunnel
  defmodule HTunnel do
    @derive Jason.Encoder
    defstruct x1: 0, x2: 0, y: 0

    def new(x1, x2, y) do
      %HTunnel{x1: x1, x2: x2, y: y}
    end
  end

  # A vertical tunnel
  defmodule VTunnel do
    @derive Jason.Encoder
    defstruct x: 0, y1: 0, y2: 0

    def new(y1, y2, x) do
      %VTunnel{x: x, y1: y1, y2: y2}
    end
  end

  def generate_map() do
    map = %GameMap{}
    root = BSP.generate_tree(map.width, map.height, @depth)
    tunnels = BSP.get_tunnels(root)

    rooms = BSP.get_rooms(root)

    %GameMap{
      map
      | rooms: rooms,
        h_tunnels:
          Enum.filter(tunnels, fn
            %HTunnel{} -> true
            _ -> false
          end),
        v_tunnels:
          Enum.filter(tunnels, fn
            %VTunnel{} -> true
            _ -> false
          end)
    }
    |> add_item_at_room(:chest, -1)
    |> add_item_at_room(:key, 3)
  end

  def create_tunnel_connections(:horizontal, left_room, right_room) do
    t = max(left_room.y1, right_room.y1) + 1
    b = min(left_room.y2, right_room.y2) - 1

    case t <= b do
      true ->
        y_pos = Enum.random(t..b)
        [HTunnel.new(left_room.x2, right_room.x1, y_pos)]

      false ->
        mid_x = div(right_room.x1 - left_room.x2, 2) + left_room.x2
        start_y = div(left_room.y2 - left_room.y1, 2) + left_room.y1
        end_y = div(right_room.y2 - right_room.y1, 2) + right_room.y1

        [
          HTunnel.new(left_room.x2, mid_x, start_y),
          VTunnel.new(start_y, end_y, mid_x),
          HTunnel.new(mid_x, right_room.x1, end_y)
        ]
    end
  end

  def create_tunnel_connections(:vertical, top_room, bottom_room) do
    l = max(top_room.x1, bottom_room.x1) + 1
    r = min(top_room.x2, bottom_room.x2) - 1

    case l <= r do
      true ->
        x_pos = Enum.random(l..r)
        [VTunnel.new(top_room.y2, bottom_room.y1, x_pos)]

      false ->
        mid_y = div(bottom_room.y1 - top_room.y2, 2) + top_room.y2
        start_x = div(top_room.x2 - top_room.x1, 2) + top_room.x1
        end_x = div(bottom_room.x2 - bottom_room.x1, 2) + bottom_room.x1

        [
          VTunnel.new(mid_y, top_room.y2, start_x),
          HTunnel.new(start_x, end_x, mid_y),
          VTunnel.new(bottom_room.y1, mid_y, end_x)
        ]
    end
  end

  defp add_item_at_room(%{rooms: rooms, items: items} = map, type, index) do
    %Room{x1: x1, x2: x2, y1: y1, y2: y2} = rooms |> Enum.at(index)

    x = Enum.random((x1 + 1)..(x2 - 1))
    y = Enum.random((y1 + 1)..(y2 - 1))

    item = Game.Item.new(type)

    %{map | items: Map.put(items, {x, y}, item)}
  end

  def colliding?(
        %GameMap{rooms: rooms, v_tunnels: v_tunnels, h_tunnels: h_tunnels},
        players,
        %Player{x: x, y: y} = player
      ) do
    colliding_with_players?(players, player) ||
      !(inside_room(rooms, x, y) || inside_tunnel(v_tunnels, h_tunnels, x, y))
  end

  defp colliding_with_players?(players, %{pid: p_pid, x: p_x, y: p_y}) do
    Enum.any?(players, fn %{pid: pid, x: x, y: y} ->
      p_pid != pid && p_x == x && p_y == y
    end)
  end

  defp inside_room(rooms, x, y) do
    Enum.any?(rooms, fn %Room{x1: x1, x2: x2, y1: y1, y2: y2} ->
      x > x1 && x < x2 && y > y1 && y < y2
    end)
  end

  defp inside_tunnel(v_tunnels, h_tunnels, x, y) do
    inside_h_tunnel =
      h_tunnels
      |> Enum.any?(fn %{x1: x1, x2: x2, y: y_tunnel} ->
        y == y_tunnel && x >= min(x1, x2) && x <= max(x1, x2)
      end)

    inside_v_tunnel =
      v_tunnels
      |> Enum.any?(fn %{x: x_tunnel, y1: y1, y2: y2} ->
        x == x_tunnel && y >= min(y1, y2) && y <= max(y1, y2)
      end)

    inside_h_tunnel || inside_v_tunnel
  end

  # Gets the positon of the chest, for winning the game
  def get_chest_pos(%GameMap{items: items}) do
    alias ProugeServer.Game.Item
    items |> Enum.find(fn {_,  %Item{type: :chest}} -> true end) |> elem(0)
  end
end
