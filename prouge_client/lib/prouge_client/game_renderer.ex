defmodule ProugeClient.GameRenderer do
  import Ratatouille.View
  alias ProugeClient.GameState
  alias ProugeClient.GameMap

  def render_bottom_label(%{game_state: %GameState{state: :not_started}}), do: []

  def render_bottom_label(%{game_state: %GameState{items: items}}) do
    text =
      items
      |> Enum.reduce("Items:", fn %{type: t, uses: uses}, acc ->
        acc <> " #{Atom.to_string(t)} (#{uses} uses),"
      end)
      |> String.replace_trailing(",", "")

    label(content: text)
  end

  def render_game(%{game_state: %GameState{state: :not_started}}), do: []

  def render_game(%{game_state: %GameState{state: :finished} = game} = model) do
    cells =
      []
      |> draw_rooms(game)
      |> draw_h_tunnels(game)
      |> draw_v_tunnels(game)
      |> draw_doors(game)

    canvas(height: model.height, width: model.width) do
      cells
    end
  end

  def render_game(%{game_state: %GameState{state: :playing} = game} = model) do
    cells =
      []
      |> draw_players(game)
      |> draw_items(game)
      |> draw_doors(game)
      |> draw_rooms(game)
      |> draw_h_tunnels(game)
      |> draw_v_tunnels(game)

    canvas(height: model.height, width: model.width) do
      cells
    end
  end

  def render_game(_model), do: []

  defp draw_players(cells, %GameState{players: players}) do
    player_cells =
      Enum.map(
        players,
        fn %{x: x, y: y} ->
          canvas_cell(x: x, y: y, char: "@", color: :blue)
        end
      )

    [player_cells | cells]
  end

  defp draw_items(cells, %GameState{map: %GameMap{items: items}}) do
    item_cells =
      Enum.map(items, fn %GameMap.Item{x: x, y: y, type: type} ->
        case type do
          :chest -> canvas_cell(x: x, y: y, char: "X", color: :red)
          :key -> canvas_cell(x: x, y: y, char: "k", color: :yellow)
        end
      end)

    [item_cells | cells]
  end

  defp draw_rooms(cells, %GameState{map: %GameMap{rooms: rooms}}) do
    walls = Enum.map(rooms, &room_cells/1)
    [walls | cells]
  end

  defp draw_h_tunnels(cells, %GameState{map: %GameMap{h_tunnels: tunnels}}) do
    tunnel_cells =
      tunnels
      |> Enum.map(fn %GameMap.HTunnel{x1: x1, x2: x2, y: y} ->
        for x <- x1..x2, do: canvas_cell(x: x, y: y, char: "#")
      end)

    [tunnel_cells | cells]
  end

  defp draw_v_tunnels(cells, %GameState{map: %GameMap{v_tunnels: tunnels}}) do
    tunnel_cells =
      tunnels
      |> Enum.map(fn %GameMap.VTunnel{x: x, y1: y1, y2: y2} ->
        for y <- y1..y2, do: canvas_cell(x: x, y: y, char: "#")
      end)

    [tunnel_cells | cells]
  end

  defp draw_doors(cells, %GameState{map: %GameMap{rooms: rooms}}) do
    door_cells =
      rooms
      |> Enum.flat_map(fn %{doors: doors} ->
        doors |> Enum.map(fn %{x: x, y: y} -> canvas_cell(x: x, y: y, char: "+") end)
      end)

    door_cells ++ cells
  end

  defp room_cells(%GameMap.Room{x1: x1, x2: x2, y1: y1, y2: y2}) do
    a = for x <- x1..x2, do: canvas_cell(x: x, y: y1, char: "-")
    b = for x <- x1..x2, do: canvas_cell(x: x, y: y2, char: "-")
    c = for y <- (y1 + 1)..(y2 - 1), do: canvas_cell(x: x1, y: y, char: "|")
    d = for y <- (y1 + 1)..(y2 - 1), do: canvas_cell(x: x2, y: y, char: "|")

    insides =
      for x <- (x1 + 1)..(x2 - 1), y <- (y1 + 1)..(y2 - 1), do: canvas_cell(x: x, y: y, char: ".")

    [insides, a, b, c | d]
  end
end
