defmodule ProugeServer.GameMap do
  alias ProugeServer.GameMap
  alias ProugeServer.Game
  alias ProugeServer.Game.Player
  alias ProugeServer.BSP
  @derive Jason.Encoder

  # Recursion depth to use with binary space partitioning room generation
  @depth 5
  # Width of the map
  @width 110
  # Height of the map
  @height 30

  defstruct rooms: [], h_tunnels: [], v_tunnels: [], items: %{}, width: @width, height: @height

  # A room to be displayed
  defmodule Room do
    @derive {Jason.Encoder, only: [:x1, :x2, :y1, :y2, :doors]}
    defstruct x1: 0, x2: 0, y1: 0, y2: 0, discovered_by: [], doors: []

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
    @derive {Jason.Encoder, only: [:x1, :x2, :y]}
    defstruct x1: 0, x2: 0, y: 0, discovered_by: []

    def new(x1, x2, y) do
      %HTunnel{x1: x1, x2: x2, y: y}
    end

    # Returns true if x, y is inside a tunnel
    def inside?(%HTunnel{x1: x1, x2: x2, y: y_t}, x, y) do
      y == y_t && x >= min(x1, x2) && x <= max(x1, x2)
    end
  end

  # A vertical tunnel
  defmodule VTunnel do
    @derive {Jason.Encoder, only: [:x, :y1, :y2]}
    defstruct x: 0, y1: 0, y2: 0, discovered_by: []

    def new(y1, y2, x) do
      %VTunnel{x: x, y1: y1, y2: y2}
    end

    # Returns true if x, y is inside a tunnel
    def inside?(%VTunnel{x: x_t, y1: y1, y2: y2}, x, y) do
      x_t == x && y >= min(y1, y2) && y <= max(y1, y2)
    end
  end

  # Generated a game map
  def generate_map() do
    map = %GameMap{}
    # Generates the binary space partiotioning (BSP) tree
    root = BSP.generate_tree(map.width, map.height, @depth)
    tunnels = BSP.get_tunnels(root)

    # Gets all rooms from the BSP and adds doors to each room based on tunnels
    rooms = BSP.get_rooms(root) |> Enum.map(fn room -> add_doors(room, tunnels) end)

    # Horizontal tunnels
    h_tunnels =
      Enum.filter(tunnels, fn
        %HTunnel{} -> true
        _ -> false
      end)

    # Vertical tunnels
    v_tunnels =
      Enum.filter(tunnels, fn
        %VTunnel{} -> true
        _ -> false
      end)

    # Add chest att last room and return
    %GameMap{map | rooms: rooms, h_tunnels: h_tunnels, v_tunnels: v_tunnels}
    |> add_item_at_room(:chest, -1)
  end

  # Creates and returns tunnels between left and right rooms, used in BSP generation
  @spec create_tunnel_connections(:horizontal | :vertical, %Room{}, %Room{}) :: [
          %HTunnel{} | %VTunnel{}
        ]
  def create_tunnel_connections(:horizontal, left_room, right_room) do
    # "lowest" y1 coordinate
    top = max(left_room.y1, right_room.y1) + 1
    # "highest" y2 coordinate
    bottom = min(left_room.y2, right_room.y2) - 1

    if top <= bottom do
      # If "lowest" y1 is above "highest" y2, we can draw a straight tunnel
      y_pos = Enum.random(top..bottom)
      [HTunnel.new(left_room.x2, right_room.x1, y_pos)]
    else
      # Otherwise we need to draw 2 horizontal and one vertical tunnel to connect them

      # The midpoint in x-coordinates between the rooms, this is the x-coordinate of the vertical tunnel
      mid_x = div(right_room.x1 - left_room.x2, 2) + left_room.x2
      # The vertical tunnel goes between the midpoint of left and right rooms in the y-axis
      start_y = div(left_room.y2 - left_room.y1, 2) + left_room.y1
      end_y = div(right_room.y2 - right_room.y1, 2) + right_room.y1

      [
        HTunnel.new(left_room.x2, mid_x, start_y),
        VTunnel.new(start_y, end_y, mid_x),
        HTunnel.new(mid_x, right_room.x1, end_y)
      ]
    end
  end

  # Creates and returns tunnels between top and bottom rooms, used in BSP generation
  def create_tunnel_connections(:vertical, top_room, bottom_room) do
    # rightmost x1 coordinate
    left = max(top_room.x1, bottom_room.x1) + 1
    # leftmost x2 coordinate
    right = min(top_room.x2, bottom_room.x2) - 1

    if left <= right do
      # If rightmost x1 left of leftmost x2, we can draw a straight tunnel
      x_pos = Enum.random(left..right)
      [VTunnel.new(top_room.y2, bottom_room.y1, x_pos)]
    else
      # Otherwise we need to draw 2 vertical and one horizontal tunnel to connect them

      # The midpoint in the y-axis between the rooms, this is the y-coordinate of the vertical tunnel
      mid_y = div(bottom_room.y1 - top_room.y2, 2) + top_room.y2
      # The horizontal tunnel goes between the midpoint of top and bottom rooms in the x-axis
      start_x = div(top_room.x2 - top_room.x1, 2) + top_room.x1
      end_x = div(bottom_room.x2 - bottom_room.x1, 2) + bottom_room.x1

      [
        VTunnel.new(mid_y, top_room.y2, start_x),
        HTunnel.new(start_x, end_x, mid_y),
        VTunnel.new(bottom_room.y1, mid_y, end_x)
      ]
    end
  end

  # Adds doors to a room, using a list of all tunnels
  defp add_doors(%Room{doors: doors, x1: x1, x2: x2, y1: y1, y2: y2} = room, tunnels) do
    doors =
      Enum.reduce(tunnels, doors, fn tunnel, acc ->
        # For each tunnel, we check any coordinates overlap with a room,
        # on that coordinate, there should be a door
        case tunnel do
          %HTunnel{x1: t_x1, x2: t_x2, y: y} ->
            if y >= y1 && y <= y2 do
              cond do
                # Right end of horizontal tunnel, left edge of room overlaps
                x1 == max(t_x1, t_x2) -> [%{x: x1, y: y} | acc]
                # Left end of horizontal tunnel, right edge of room overlaps
                x2 == min(t_x1, t_x2) -> [%{x: x2, y: y} | acc]
                true -> acc
              end
            else
              acc
            end

          %VTunnel{y1: t_y1, y2: t_y2, x: x} ->
            if x >= x1 && x <= x2 do
              cond do
                # Bottom end of vertical tunnel, top edge of room overlap
                y1 == max(t_y1, t_y2) -> [%{x: x, y: y1} | acc]
                # Top end of vertical tunnel, bottom edge of room overlap
                y2 == min(t_y1, t_y2) -> [%{x: x, y: y2} | acc]
                true -> acc
              end
            else
              acc
            end
        end
      end)

    %{room | doors: doors}
  end

  # Adds an item with a type to the map based on the index
  def add_item_at_room(%{rooms: rooms, items: items} = map, type, index) do
    # Get the room at index
    %Room{x1: x1, x2: x2, y1: y1, y2: y2} = rooms |> Enum.at(index)

    # Genrate a random position inside the room
    x = Enum.random((x1 + 1)..(x2 - 1))
    y = Enum.random((y1 + 1)..(y2 - 1))

    item = Game.Item.new(type)

    # Adds the item under the {x,y} key
    %{map | items: Map.put(items, {x, y}, item)}
  end

  # Based on a map and a list of all players, check if the player is colliding
  def colliding?(
        %GameMap{rooms: rooms, v_tunnels: v_tunnels, h_tunnels: h_tunnels},
        players,
        %Player{x: x, y: y} = player
      ) do
    # A player is colliding if it collides with another player or is not inside a tunnel or roop
    colliding_with_players?(players, player) ||
      !(inside_room?(rooms, x, y) || inside_tunnel?(v_tunnels, h_tunnels, x, y))
  end

  # Returns true if the player collides with any other player
  defp colliding_with_players?(players, %{pid: p_pid, x: p_x, y: p_y}) do
    Enum.any?(players, fn %{pid: pid, x: x, y: y} ->
      p_pid != pid && p_x == x && p_y == y
    end)
  end

  # Returns true if x, y is inside a room
  def inside_room?(rooms, x, y) do
    Enum.any?(rooms, fn %Room{x1: x1, x2: x2, y1: y1, y2: y2} ->
      x > x1 && x < x2 && y > y1 && y < y2
    end)
  end

  # Returns true if x, y is inside either a horizontal or vertical tunnel
  defp inside_tunnel?(v_tunnels, h_tunnels, x, y) do
    inside_h_tunnel = Enum.any?(h_tunnels, fn t -> HTunnel.inside?(t, x, y) end)
    inside_v_tunnel = Enum.any?(v_tunnels, fn t -> VTunnel.inside?(t, x, y) end)

    inside_h_tunnel || inside_v_tunnel
  end

  # If player is inside a room and the room is undiscovered, add player to discovered_by
  @spec try_discover_rooms([%Room{}], Integer, Integer, pid()) :: [%Room{}]
  def try_discover_rooms(rooms, x, y, player_id) do
    Enum.map(rooms, fn %Room{x1: x1, x2: x2, y1: y1, y2: y2, discovered_by: discovered} = room ->
      # Player inside the room
      inside_room = x > x1 && x < x2 && y > y1 && y < y2

      # Discover room if player is inside and has not discovered it before
      if inside_room && !Enum.member?(discovered, player_id) do
        %{room | discovered_by: [player_id | discovered]}
      else
        room
      end
    end)
  end

  # If a player is inside a tunnel and that tunnel is undiscovered, add player to discovered_by
  @spec try_discover_tunnels([%HTunnel{} | %VTunnel{}], Integer, Integer, pid()) :: [%Room{}]
  def try_discover_tunnels(tunnels, x, y, player_id) do
    Enum.map(tunnels, fn
      %HTunnel{discovered_by: discovered} = t ->
        # If player inside a horizontal tunnel and it is undiscovered, discover it
        if HTunnel.inside?(t, x, y) && !Enum.member?(discovered, player_id) do
          %{t | discovered_by: [player_id | discovered]}
        else
          t
        end

      %VTunnel{discovered_by: discovered} = t ->
        # If player inside a vertical tunnel and it is undiscovered, discover it
        if VTunnel.inside?(t, x, y) && !Enum.member?(discovered, player_id) do
          %{t | discovered_by: [player_id | discovered]}
        else
          t
        end
    end)
  end

  # Gets the positon of the chest, for winning the game, returns {x, y}
  @spec get_chest_pos(%GameMap{}) :: {Integer, Integer}
  def get_chest_pos(%GameMap{items: items}) do
    items |> Enum.find(fn {_, %Game.Item{type: :chest}} -> true end) |> elem(0)
  end

  # Increment the number of usages of the cest, called when a new player is added
  @spec increment_chest(%GameMap{}) :: %GameMap{}
  def increment_chest(%GameMap{items: items} = game_map) do
    {key, _} = items |> Enum.find(fn {_, %Game.Item{type: :chest}} -> true end)

    %{game_map | items: Map.update!(items, key, &Game.Item.change_uses(&1, 1))}
  end
end
