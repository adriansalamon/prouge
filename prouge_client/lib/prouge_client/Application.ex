defmodule ProugeClient.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Ratatouille.Runtime.Supervisor, runtime: [app: ProugeClient.App, shutdown: :system]},
      {ProugeClient.TCPClient, []}
      # Starts a worker by calling: ProugeServer.Worker.start_link(arg)
      # {ProugeServer.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ProugeClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
