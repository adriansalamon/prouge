defmodule ProugeServer.TCPServer do
  @moduledoc """
  A process which accepts incoming TCP connection requests, starts client
  processes for each connection, and hands over the TCP communiation to the
  client processes.
  """

  use Task, restart: :permanent
  require Logger

  def start_link(port) do
    Logger.info("Starting TCP server, running on pid #{inspect(self())}...")

    Task.start_link(__MODULE__, :accept, [port])
  end

  def accept(port) do
    Process.register(self(), ProugeServer.TCPServer)

    # Starts the tcp server
    {:ok, listen_socket} =
      :gen_tcp.listen(port, [:binary, packet: 4, active: :once, reuseaddr: true])

    Logger.info("TCP server accepting connections on port #{port}")
    loop_acceptor(listen_socket)
  end

  defp loop_acceptor(listen_socket) do
    # Accepts incoming tcp connection requests
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)

    Logger.info(
      "Client #{inspect(client_socket)} from socket #{inspect(listen_socket)} connected to TCPServer"
    )

    # Starts a client process to handle new game client under our dynamic supervisor
    {:ok, pid} =
      DynamicSupervisor.start_child(
        ProugeServer.DynamicSupervisor,
        {ProugeServer.Client, client_socket}
      )

    # Hands control over the tcp communication to the client proces
    :ok = :gen_tcp.controlling_process(client_socket, pid)

    # Recursivly listen for new connection request
    loop_acceptor(listen_socket)
  end
end
