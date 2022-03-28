defmodule ProugeServer.GameMap do
  alias ProugeServer.GameMap, as: GameMap
  alias ProugeServer.Game.Player, as: Player
  @derive Jason.Encoder

  @depth 2
  @width 40
  @height 30

  defstruct rooms: [], h_tunnels: [], v_tunnels: [], width: @width, height: @height

  # Item on the map
  defmodule Item do
    alias GameMap.Item, as: Item
    @derive Jason.Encoder
    defstruct x: 0, y: 0, type: nil

    def new(x, y, type) do
      %Item{x: x, y: y, type: type}
    end
  end

  # A room to be displayed
  defmodule Room do
    @derive Jason.Encoder
    defstruct x1: 0, x2: 0, y1: 0, y2: 0, items: []

    def new(x, y, w, h) do
      %Room{x1: x, y1: y, x2: x + w, y2: y + h}
    end

    # Returns the center of a room
    def center(%Room{} = room) do
      center_x = div(room.x1 + room.x2, 2)
      center_y = div(room.y1 + room.y2, 2)
      %{x: center_x, y: center_y}
    end

    # Adds an item with typ to a room
    def add_item(%Room{x1: x1, x2: x2, y1: y1, y2: y2, items: items} = room, type) do
      x = Enum.random((x1 + 1)..(x2 + 1))
      y = Enum.random((y1 + 1)..(y2 - 1))

      %Room{room | items: [GameMap.Item.new(x, y, type) | items]}
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

  defmodule BSP do
    alias GameMap.BSP, as: Node

    defstruct x1: 0,
              x2: 0,
              y1: 0,
              y2: 0,
              split_dir: nil,
              room: nil,
              tunnels: [],
              left: nil,
              right: nil

    @tol 0.2
    @min_height 4
    @min_width 8
    # High value leads to larger rooms
    @room_gen_size 6

    def generate_tree(width, height, depth) do
      generate_rects(%Node{x2: width, y2: height}, depth - 1)
      |> generate_rooms()
      |> generate_tunnels()
    end

    def get_tunnels(%Node{tunnels: [], left: nil, right: nil}) do
      []
    end

    def get_tunnels(%Node{tunnels: tunnels, left: left, right: right}) do
      case tunnels do
        [] -> get_tunnels(right) ++ get_tunnels(left)
        t -> get_tunnels(right) ++ t ++ get_tunnels(left)
      end
    end

    def get_rooms(%Node{left: nil, right: nil, room: room}) do
      [room]
    end

    def get_rooms(%Node{left: left, right: right, room: nil}) do
      get_rooms(right) ++ get_rooms(left)
    end

    def generate_tunnels(%Node{left: nil, right: nil, room: %Room{}} = node), do: node

    def generate_tunnels(%Node{split_dir: :horizontal, left: top, right: bottom} = node) do
      top_room = get_rooms(top) |> Enum.max_by(fn %Room{y2: y2} -> y2 end)
      bottom_room = get_rooms(bottom) |> Enum.min_by(fn %Room{y1: y1} -> y1 end)

      tunnels = GameMap.create_tunnel_connections(:vertical, top_room, bottom_room)

      node
      |> Map.put(:tunnels, tunnels)
      |> Map.update!(:left, &generate_tunnels/1)
      |> Map.update!(:right, &generate_tunnels/1)
    end

    def generate_tunnels(%Node{split_dir: :vertical, left: left, right: right} = node) do
      left_room = get_rooms(left) |> Enum.max_by(fn %Room{x2: x2} -> x2 end)
      right_room = get_rooms(right) |> Enum.min_by(fn %Room{x1: x1} -> x1 end)

      tunnels = GameMap.create_tunnel_connections(:horizontal, left_room, right_room)

      node
      |> Map.put(:tunnels, tunnels)
      |> Map.update!(:left, &generate_tunnels/1)
      |> Map.update!(:right, &generate_tunnels/1)
    end

    defp generate_rooms(%Node{x1: x1, x2: x2, y1: y1, y2: y2, left: nil, right: nil} = leaf) do
      rect_width = x2 - x1
      rect_height = y2 - y1

      x = Enum.random((x1 + 1)..(x1 + div(rect_width, @room_gen_size)))
      y = Enum.random((y1 + 1)..(y1 + div(rect_height, @room_gen_size)))
      w = Enum.random(@min_width..(x2 - x - 2))
      h = Enum.random(@min_height..(y2 - y - 2))

      %{leaf | room: Room.new(x, y, w, h)}
    end

    defp generate_rooms(%Node{left: _, right: _} = node) do
      node
      |> Map.update!(:left, &generate_rooms/1)
      |> Map.update!(:right, &generate_rooms/1)
    end

    defp generate_rects(leaf, depth) when depth == 0 do
      leaf
    end

    defp generate_rects(%Node{x1: x1, x2: x2, y1: y1, y2: y2} = root, depth) do
      width = x2 - x1
      height = y2 - y1

      split_dir =
        case height < width do
          true -> :vertical
          false -> :horizontal
        end

      case split_dir do
        :vertical ->
          min_range = (x1 + @tol * width) |> round()
          max_range = (x2 - @tol * width) |> round()
          split_pos = Enum.random(min_range..max_range)

          case split_pos - x1 > @min_width && x2 - split_pos > @min_width do
            true ->
              left = generate_rects(%Node{x1: x1, x2: split_pos, y1: y1, y2: y2}, depth - 1)
              right = generate_rects(%Node{x1: split_pos, x2: x2, y1: y1, y2: y2}, depth - 1)
              %{root | split_dir: split_dir, left: left, right: right}

            false ->
              root
          end

        :horizontal ->
          min_range = (y1 + @tol * height) |> round()
          max_range = (y2 - @tol * height) |> round()
          split_pos = Enum.random(min_range..max_range)

          case split_pos - y1 > @min_height && y2 - split_pos > @min_height do
            true ->
              top = generate_rects(%Node{x1: x1, x2: x2, y1: y1, y2: split_pos}, depth - 1)
              bottom = generate_rects(%Node{x1: x1, x2: x2, y1: split_pos, y2: y2}, depth - 1)
              %{root | split_dir: split_dir, left: top, right: bottom}

            false ->
              root
          end
      end
    end
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
    |> add_item_at_room!(:chest, -1)
  end

  defp add_item_at_room!(%{rooms: rooms} = map, type, index) do
    len = length(rooms)

    adjusted_index =
      case index < 0 do
        true -> len + index
        false -> index
      end

    updated_rooms =
      rooms
      |> Enum.with_index()
      |> Enum.map(fn {room, i} ->
        case i == adjusted_index do
          true -> Room.add_item(room, type)
          false -> room
        end
      end)

    %{map | rooms: updated_rooms}
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
  def get_chest_pos(%GameMap{rooms: rooms}) do
    %Room{items: items} =
      Enum.find(rooms, fn %Room{items: items} ->
        Enum.any?(
          items,
          fn
            %Item{type: :chest} -> true
          end
        )
      end)

    %Item{x: x, y: y} = Enum.find(items, fn %Item{type: :chest} -> true end)

    {x, y}
  end
end
