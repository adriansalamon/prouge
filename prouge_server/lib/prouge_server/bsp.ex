defmodule ProugeServer.BSP do
  alias ProugeServer.BSP, as: Node
  alias ProugeServer.GameMap
  alias ProugeServer.GameMap.Room

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
