defmodule ProugeClient.App do
  @behaviour Ratatouille.App
  import Ratatouille.View
  import Ratatouille.Constants, only: [key: 1]
  alias ProugeClient.TCPClient, as: TCPClient

  @up key(:arrow_up)
  @down key(:arrow_down)
  @left key(:arrow_left)
  @right key(:arrow_right)
  @arrows [@up, @down, @left, @right]

  def init(%{window: window}) do
    TCPClient.set_client(self())
    TCPClient.connect('localhost', 6969)
    %{
      game_state: %{},
      height: window.height - 2,
      width: window.width - 2
    }
  end

  def update(model, msg) do
    case msg do
      {:event, %{key: key}} when key in @arrows ->
        TCPClient.send_command(%{move: key |> to_direction()})
        model
      {:event, {:new_game_state, state}} ->
        Map.put(model, :game_state, state)
      _ -> model
    end
  end

  def render(model) do
    ProugeClient.GameRenderer.render(model)
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
