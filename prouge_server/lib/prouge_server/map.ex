defmodule ProugeServer.Map do
  alias ProugeServer.Map, as: Map
  @derive Jason.Encoder
  defstruct rooms: [], h_tunnels: [], v_tunnels: [], width: 200, height: 200

  defmodule Room do
    @derive Jason.Encoder
    defstruct x1: 0, x2: 0, y1: 0, y2: 0

    def new(x, y, w, h) do
      %Room{x1: x, y1: y, x2: x + w, y2: y + h}
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
    map =
      %Map{}
      |> add_room(Room.new(20, 15, 10, 15))
      |> add_room(Room.new(50, 15, 15, 10))
      |> add_h_tunnel(25, 55, 23)
      |> add_v_tunnel(15, 10, 23)

    map
  end

  def add_room(%Map{rooms: rooms} = map, room) do
    %Map{map | rooms: [room | rooms]}
  end

  def add_h_tunnel(%Map{h_tunnels: c} = map, x1, x2, y) do
    new_c = %HCorridor{x1: min(x1, x2), x2: max(x1, x2), y: y}
    %Map{map | h_tunnels: [new_c | c]}
  end


  def add_v_tunnel(%Map{v_tunnels: cs} = map, y1, y2, x) do
    c = %VCorridor{x: x, y1: min(y1,y2), y2: max(y1,y2)}
    %Map{map | v_tunnels: [c | cs]}
  end


  def colliding?(%Map{rooms: rooms, v_tunnels: v_tunnels, h_tunnels: h_tunnels}, x, y) do
    # Must be inside a room
    !(inside_room(rooms, x, y) || inside_tunnel(v_tunnels, h_tunnels, x, y))
  end

  defp inside_room(rooms, x, y) do
    Enum.any?(rooms, fn %Room{x1: x1, x2: x2, y1: y1, y2: y2} ->
      x > x1 && x < x2 && y > y1 && y < y2
    end)
  end

  defp inside_tunnel(v_tunnels, h_tunnels, x, y) do
    inside_h_tunnel = h_tunnels |> Enum.any?(fn %{x1: x1, x2: x2, y: y_tunnel} ->
      y == y_tunnel && x >= x1 && x <= x2
    end)

    inside_v_tunnel = v_tunnels |> Enum.any?(fn %{x: x_tunnel, y1: y1, y2: y2} ->
      x == x_tunnel && y >= y1 && y <= y2
    end)

    inside_h_tunnel || inside_v_tunnel

  end
end
