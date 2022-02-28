defmodule ProugeServer.TCPServer do
  require Logger
  use Task, restart: :permanent

  def start_link(port) do
    Logger.info "Starting TCP server in pid #{inspect(self())}..."

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    Process.register(self(), Prouge.TCPServer)

    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: :once, reuseaddr: true])

    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(listen_socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Logger.info "Client #{inspect(client)} from socket #{inspect(socket)} connected to server"

    {:ok, pid} = DynamicSupervisor.start_child(ProugeServer.DynamicSupervisor, {ProugeServer.Client, client})
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

end
