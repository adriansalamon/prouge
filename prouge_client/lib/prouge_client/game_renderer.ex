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


  defp render_game(%{game_state: %{"players" => players}} = model) do
    player_cells =
      Enum.map(
        players,
        fn %{"x" => x, "y" => y} ->
          canvas_cell(x: x, y: y, char: "@")
        end
      )

    canvas(height: model.height, width: model.width) do
      player_cells
    end
  end

  defp render_game(_model), do: []
end
