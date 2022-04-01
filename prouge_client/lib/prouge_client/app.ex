defmodule ProugeClient.App do
  @moduledoc """
  The Ratatouille app that runs the user interface.
  """
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
    # Adds the ratatoulle app pid to the tcp client so that it can send messages to it
    TCPClient.register_app_pid(self())
    # Connect to the game server
    TCPClient.connect('localhost', 6969)

    # Initial ratatoulle model
    %{
      game_state: %GameState{},
      height: window.height - 2,
      width: window.width - 2,
      overlay_toggled: false
    }
  end

  # Callback when an event is triggered
  def update(model, msg) do
    case msg do
      {:event, %{ch: ?h}} ->
        # When pressing "h" for help
        case model.game_state.state do
          :playing -> %{model | overlay_toggled: !model.overlay_toggled}
          _ -> model
        end

      {:event, %{key: key}} when key in @arrows ->
        # Trying to move, send command {"move": "direction"}
        TCPClient.send_command(%{move: key |> key_to_direction()})
        model

      {:event, {:new_game_state, state}} ->
        # New game state recieved from TCP client process

        # Display overlayed if game is finished
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
        # Render the main game
        GameRenderer.render_game(model)
      end

      # Render the overlay
      if model.overlay_toggled do
        {title, text} =
          case model.game_state.state do
            :playing ->
              {"Help, dismiss with [h]",
               "Move with arrow keys. In order to win, all players must pick up a key (marked with k) and
                unlock the chest (marked with X). To unlock the chest, you need to walk over the X."}

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

  defp key_to_direction(key) do
    case key do
      @up -> :up
      @down -> :down
      @right -> :right
      @left -> :left
    end
  end
end
