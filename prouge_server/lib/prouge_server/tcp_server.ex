defmodule ProugeServer.TCPServer do
  use Task, restart: :permanent
  require Logger

  def start_link (port) do
    Logger.info("Starting TCP server, running on pid #{inspect(self())}...")

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    Process.register(self(), ProugeServer.TCPServer)

    {:ok, socket} = :gen_tcp.listen(port, [ :binary, packet: :line, active: :once, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Logger.info("Client #{inspect(client)} from socket #{inspect(socket)} connected to TCPServer")

    {:ok, pid} = DynamicSupervisor.start_child(ProugeServer.DynamicSupervisor, {ProugeServer.Client, client})
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

end
