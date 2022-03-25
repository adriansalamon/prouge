defmodule ProugeServer.GameMap do
  alias ProugeServer.GameMap, as: GameMap
  alias ProugeServer.Game.Player, as: Player
  import Logger
  @derive Jason.Encoder
  defstruct rooms: [], h_tunnels: [], v_tunnels: [], width: 110, height: 30

  @room_max_size 10
  @room_min_size 6
  @max_rooms 20

  defmodule Room do
    @derive Jason.Encoder
    defstruct x1: 0, x2: 0, y1: 0, y2: 0

    def new(x, y, w, h) do
      %Room{x1: x, y1: y, x2: x + w, y2: y + h}
    end

    def intersecting?(room_1, room_2) do
      room_1.x1 <= room_2.x2 && room_1.x2 >= room_2.x1 &&
        room_1.y1 <= room_2.y2 && room_1.y2 >= room_2.y1
    end

    def center(%Room{} = room) do
      center_x = div(room.x1 + room.x2, 2)
      center_y = div(room.y1 + room.y2, 2)
      %{x: center_x, y: center_y}
    end
  end

  defmodule Rect do
    alias GameMap.Rect, as: Node

    defstruct x1: 0,
              x2: 0,
              y1: 0,
              y2: 0,
              split_dir: nil,
              room: nil,
              tunnel: nil,
              left: nil,
              right: nil

    @default_depth 3
    @tol 0.2
    @min_height 4
    @min_width 8

    def generate_tree(width, height, depth) do
      generate_rects(%Node{x2: width, y2: height}, depth - 1)
      |> generate_rooms()
    end

    def get_rooms(%Node{left: nil, right: nil, room: room}) do
      [room]
    end

    def get_rooms(%Node{left: left, right: right, room: nil}) do
      get_rooms(right) ++ get_rooms(left)
    end

    defp generate_rooms(%Node{x1: x1, x2: x2, y1: y1, y2: y2, left: nil, right: nil} = leaf) do
      rect_width = x2 - x1
      rect_height = y2 - y1

      x = Enum.random((x1 + 1)..(x1 + div(rect_width, 10)))
      y = Enum.random((y1 + 1)..(y1 + div(rect_height, 10)))
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
        case {height < @min_height, width < @min_width} do
          {true, true} -> :none
          {true, false} -> :vertical
          {false, true} -> :horizontal
          _ -> Enum.random([:vertical,:vertical,:vertical,:horizontal,:horizontal])
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

        :none ->
          root
      end
    end
  end

  defmodule HCorridor do
    @derive Jason.Encoder
    defstruct x1: 0, x2: 0, y: 0
  end

  defmodule VCorridor do
    @derive Jason.Encoder
    defstruct x: 0, y1: 0, y2: 0
  end

  def generate_map() do
    # map =
    #   Enum.reduce(0..@max_rooms, %GameMap{}, fn _n, map ->
    #     # Create rooms
    #     w = Enum.random(@room_min_size..@room_max_size)
    #     h = Enum.random(@room_min_size..@room_max_size)
    #     x = Enum.random(0..(map.width - w))
    #     y = Enum.random(0..(map.height - h))

    #     new_room = Room.new(x, y, w, h)
    #     intersecting = Enum.any?(map.rooms, fn room -> Room.intersecting?(room, new_room) end)

    #     case intersecting do
    #       true -> map
    #       false -> add_room(map, new_room)
    #     end
    #   end)
    #   |> connect_rooms()
    map = %GameMap{}
    root = Rect.generate_tree(map.width, map.height, 6)

    Logger.debug("Generated map: #{inspect(root)}")
    %GameMap{map | rooms: Rect.get_rooms(root)}
  end

  defp connect_rooms(%GameMap{rooms: rooms} = map) do
    rooms
    |> Enum.drop(1)
    |> Enum.zip(rooms)
    |> Enum.reduce(map, fn {room1, room2}, acc ->
      %{x: prev_x, y: prev_y} = Room.center(room1)
      %{x: new_x, y: new_y} = Room.center(room2)

      case Enum.random(0..1) do
        0 ->
          acc
          |> add_v_tunnel(prev_y, new_y, prev_x)
          |> add_h_tunnel(prev_x, new_x, new_y)

        1 ->
          acc
          |> add_h_tunnel(prev_x, new_x, prev_y)
          |> add_v_tunnel(prev_y, new_y, new_x)
      end
    end)
  end

  defp add_room(%GameMap{rooms: rooms} = map, room) do
    %GameMap{map | rooms: [room | rooms]}
  end

  defp add_h_tunnel(%GameMap{h_tunnels: c} = map, x1, x2, y) do
    new_c = %HCorridor{x1: min(x1, x2), x2: max(x1, x2), y: y}
    %GameMap{map | h_tunnels: [new_c | c]}
  end

  defp add_v_tunnel(%GameMap{v_tunnels: cs} = map, y1, y2, x) do
    c = %VCorridor{x: x, y1: min(y1, y2), y2: max(y1, y2)}
    %GameMap{map | v_tunnels: [c | cs]}
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
        y == y_tunnel && x >= x1 && x <= x2
      end)

    inside_v_tunnel =
      v_tunnels
      |> Enum.any?(fn %{x: x_tunnel, y1: y1, y2: y2} ->
        x == x_tunnel && y >= y1 && y <= y2
      end)

    inside_h_tunnel || inside_v_tunnel
  end
end
