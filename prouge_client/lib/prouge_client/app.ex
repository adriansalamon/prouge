defmodule ProugeClient.App do
  @behaviour Ratatouille.App
  import Ratatouille.Constants, only: [key: 1]
  import Ratatouille.View
  alias ProugeClient.TCPClient
  alias ProugeClient.GameState
  alias ProugeClient.GameRenderer

  @up key(:arrow_up)
  @down key(:arrow_down)
  @left key(:arrow_left)
  @right key(:arrow_right)
  @arrows [@up, @down, @left, @right]

  def init(%{window: window}) do
    TCPClient.set_client(self())
    TCPClient.connect('localhost', 6969)

    %{
      game_state: %GameState{},
      height: window.height - 2,
      width: window.width - 2,
      overlay_toggled: false
    }
  end

  def update(model, msg) do
    case msg do
      {:event, %{ch: ?h}} ->
        case model.game_state.state do
          :playing -> %{model | overlay_toggled: !model.overlay_toggled}
          _ -> model
        end

      {:event, %{key: key}} when key in @arrows ->
        TCPClient.send_command(%{move: key |> to_direction()})
        model

      {:event, {:new_game_state, state}} ->
        overlay_toggled =
          case state.state do
            :finished -> true
            _ -> model.overlay_toggled
          end

        model |> Map.put(:game_state, state) |> Map.put(:overlay_toggled, overlay_toggled)

      _ ->
        model
    end
  end

  def render(model) do
    bottom_bar =
      bar do
        GameRenderer.render_bottom_label(model)
      end

    view(bottom_bar: bottom_bar) do
      panel(
        title: "Prouge game - press [h] for help",
        height: :fill,
        padding: 0
      ) do
        GameRenderer.render_game(model)
      end

      if model.overlay_toggled do
        {title, text} =
          case model.game_state.state do
            :playing ->
              {"Help, dismiss with [h]",
               "Move with arrow keys. In order to win, all players must pick up a key (marked with k) and unlock the chest (marked with X). To unlock the chest, you need to walk over the X."}

            :finished ->
              {"You won!", "Congratulations!\nPress [q] to exit"}

            _ ->
              {"", ""}
          end

        overlay do
          panel(title: title, height: :fill) do
            label(content: text, wrap: true)
          end
        end
      end
    end
  end

  defp to_direction(key) do
    case key do
      @up -> :up
      @down -> :down
      @right -> :right
      @left -> :left
    end
  end
end
