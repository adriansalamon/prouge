defmodule ProugeServer.BSP do
  @moduledoc """
  Functions for handling the binary space partitioning (BSP) generation
  of the map. A BSP node is a rectangle that can either host a room (leaf in tree)
  or left and right children nodes and a list of tunnels to connect them. When generating
  nodes are recursivly randomly split vertically or horizontally to create smaller rooms.
  """

  alias ProugeServer.BSP, as: Node
  alias ProugeServer.GameMap
  alias ProugeServer.GameMap.Room

  defstruct x1: 0,
            x2: 0,
            y1: 0,
            y2: 0,
            # Either :horizontal or :vertical
            split_dir: nil,
            # Room inside the node
            room: nil,
            tunnels: [],
            # Left/top child node
            left: nil,
            # Right/bottom child node
            right: nil

  # The minimum ratio to split nodes at, a node should not be split into one tiny and one huge node
  @tol 0.2
  # Minimum height of a node
  @min_height 4
  # Minimum width of a node
  @min_width 8
  # High value leads to larger rooms
  @room_gen_size 6

  # Generates the BSP
  def generate_tree(width, height, depth) do
    %Node{x2: width, y2: height}
    |> generate_nodes(depth - 1)
    |> generate_rooms()
    |> generate_tunnels()
  end

  # Base case when depth is 0
  defp generate_nodes(leaf, depth) when depth == 0, do: leaf

  defp generate_nodes(%Node{x1: x1, x2: x2, y1: y1, y2: y2} = root, depth) do
    width = x2 - x1
    height = y2 - y1

    split_dir =
      case height < width do
        true -> :vertical
        false -> :horizontal
      end

    case split_dir do
      :vertical ->
        # Randomly generates the split position
        min_range = (x1 + @tol * width) |> round()
        max_range = (x2 - @tol * width) |> round()
        split_pos = Enum.random(min_range..max_range)

        if split_pos - x1 > @min_width && x2 - split_pos > @min_width do
          # Ok to split, recursivly generate nodes to the left and right
          left = generate_nodes(%Node{x1: x1, x2: split_pos, y1: y1, y2: y2}, depth - 1)
          right = generate_nodes(%Node{x1: split_pos, x2: x2, y1: y1, y2: y2}, depth - 1)
          %{root | split_dir: split_dir, left: left, right: right}
        else
          # Nodes will become too small, stop splitting and recursing
          root
        end

      :horizontal ->
        # Randomly generates the split position
        min_range = (y1 + @tol * height) |> round()
        max_range = (y2 - @tol * height) |> round()
        split_pos = Enum.random(min_range..max_range)

        if split_pos - y1 > @min_height && y2 - split_pos > @min_height do
          # Ok to split, recursivly generate nodes to the top and bottom
          top = generate_nodes(%Node{x1: x1, x2: x2, y1: y1, y2: split_pos}, depth - 1)
          bottom = generate_nodes(%Node{x1: x1, x2: x2, y1: split_pos, y2: y2}, depth - 1)
          %{root | split_dir: split_dir, left: top, right: bottom}
        else
          # Nodes will become too small, stop splitting and recursing
          root
        end
    end
  end

  # When at a leaf node, add a room inside the node
  defp generate_rooms(%Node{x1: x1, x2: x2, y1: y1, y2: y2, left: nil, right: nil} = leaf) do
    node_width = x2 - x1
    node_height = y2 - y1

    # Generate x, y, width and height of the room randomly inside the bounds of the node
    x = Enum.random((x1 + 1)..(x1 + div(node_width, @room_gen_size)))
    y = Enum.random((y1 + 1)..(y1 + div(node_height, @room_gen_size)))
    w = Enum.random(@min_width..(x2 - x - 2))
    h = Enum.random(@min_height..(y2 - y - 2))

    %{leaf | room: Room.new(x, y, w, h)}
  end

  # If not at a leaf, recurse to the left and right
  defp generate_rooms(%Node{left: _, right: _} = node) do
    node
    |> Map.update!(:left, &generate_rooms/1)
    |> Map.update!(:right, &generate_rooms/1)
  end

  # When at a leaf node, return
  def generate_tunnels(%Node{left: nil, right: nil, room: %Room{}} = leaf), do: leaf

  def generate_tunnels(%Node{split_dir: :horizontal, left: top, right: bottom} = node) do
    # Finds the room that is "lowest" out of the top children nodes
    top_room = get_rooms(top) |> Enum.max_by(fn %Room{y2: y2} -> y2 end)
    # Finds the room that is the "highest" out of the bottom children nodes
    bottom_room = get_rooms(bottom) |> Enum.min_by(fn %Room{y1: y1} -> y1 end)

    # A list of tunnel entites that connects the children nodes togheter
    tunnels = GameMap.create_tunnel_connections(:vertical, top_room, bottom_room)

    # Add the tunnels to this node and recurse
    node
    |> Map.put(:tunnels, tunnels)
    |> Map.update!(:left, &generate_tunnels/1)
    |> Map.update!(:right, &generate_tunnels/1)
  end

  def generate_tunnels(%Node{split_dir: :vertical, left: left, right: right} = node) do
    # Finds the room that is "rightmost" out of the left children nodes
    left_room = get_rooms(left) |> Enum.max_by(fn %Room{x2: x2} -> x2 end)
    # Finds the room that is "leftmost" out of the right children nodes
    right_room = get_rooms(right) |> Enum.min_by(fn %Room{x1: x1} -> x1 end)

    # A list of tunnel entites that connects the children nodes togheter
    tunnels = GameMap.create_tunnel_connections(:horizontal, left_room, right_room)

    # Add the tunnels to this node and recurse
    node
    |> Map.put(:tunnels, tunnels)
    |> Map.update!(:left, &generate_tunnels/1)
    |> Map.update!(:right, &generate_tunnels/1)
  end

  # When at a leaf, return an empty list
  def get_tunnels(%Node{tunnels: [], left: nil, right: nil}), do: []

  @spec get_tunnels(%Node{}) :: [%GameMap.HTunnel{} | %GameMap.VTunnel{}]
  def get_tunnels(%Node{tunnels: tunnels, left: left, right: right}) do
    case tunnels do
      # If node has no tunnels, recurse
      [] -> get_tunnels(right) ++ get_tunnels(left)
      # If node has tunnels, add and recurse, does in-order-traversal
      t -> get_tunnels(right) ++ t ++ get_tunnels(left)
    end
  end

  # When at a leaf, return the room inside it
  def get_rooms(%Node{left: nil, right: nil, room: room}), do: [room]

  @spec get_rooms(%Node{}) :: [%GameMap.Room{}]
  def get_rooms(%Node{left: left, right: right, room: nil}) do
    # Recursively get all rooms from all leaves
    get_rooms(right) ++ get_rooms(left)
  end
end
