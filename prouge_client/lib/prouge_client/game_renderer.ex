defmodule ProugeClient.GameRenderer do
  import Ratatouille.View

  def render(model) do
    view do
      panel(
        title: "Prouge gem - move with arrow keys silly",
        height: :fill,
        padding: 0
      ) do
        render_game(model)
      end
    end
  end

  defp render_game(%{game_state: game} = model) when game != %{} do
    cells = []
      |> draw_players(game)
      |> draw_rooms(game)
      |> draw_h_tunnels(game)
      |> draw_v_tunnels(game)

    canvas(height: model.height, width: model.width) do
      cells
    end
  end

  defp render_game(_model), do: []

  defp draw_players(cells, %{"players" => players}) do
    player_cells =
      Enum.map(
        players,
        fn %{"x" => x, "y" => y} ->
          canvas_cell(x: x, y: y, char: "@", color: :blue)
        end
      )

    [player_cells | cells]
  end

  defp draw_rooms(cells, %{"map" => %{"rooms" => rooms}}) do
    walls = Enum.map(rooms, &room_borders/1)
    [walls | cells]
  end


  defp draw_h_tunnels(cells, %{"map" => %{"h_tunnels" => tunnels}}) do
    tunnel_cells =  tunnels |> Enum.map(fn %{"x1" => x1, "x2" => x2, "y" => y} ->
      for x <- x1..x2, do: canvas_cell(x: x, y: y, char: "#")
    end)
    [tunnel_cells | cells]
  end

  defp draw_v_tunnels(cells, %{"map" => %{"v_tunnels" => tunnels}}) do
    tunnel_cells = tunnels |> Enum.map(fn %{"x" => x, "y1" => y1, "y2" => y2} ->
      for y <- y1..y2, do: canvas_cell(x: x, y: y, char: "#")
    end)
    [tunnel_cells | cells]
  end

  defp room_borders(%{"x1" => x1, "x2" => x2, "y1" => y1, "y2" => y2}) do
    a = for x <- x1..x2, do: canvas_cell(x: x, y: y1, char: "-")
    b = for x <- x1..x2, do: canvas_cell(x: x, y: y2, char: "-")
    c = for y <- (y1 + 1)..(y2 - 1), do: canvas_cell(x: x1, y: y, char: "|")
    d = for y <- (y1 + 1)..(y2 - 1), do: canvas_cell(x: x2, y: y, char: "|")

    insides = for x <- (x1+1)..(x2-1), y <- (y1+1)..(y2-1), do: canvas_cell(x: x, y: y, char: ".")

    [insides, a, b, c | d]
  end
end
