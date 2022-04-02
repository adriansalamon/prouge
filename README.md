# Prouge

A simple networked rougelike with server and client written in Elixir. Contains `prouge_client` and `prouge_server`. To run the game, you will need to have one server instance running and connect any number of clients.

## How to run

You will need to have Elixir installed on your computer, refer to https://elixir-lang.org/install.html for information on how to install.

### Server

Make sure that you are in the `prouge_server` directory. Defaults to using port 3000, if you want to use something else,
set `PROUGE_PORT` to some other value.

```
mix deps.get
mix run --no-halt
```

### Client 

Make sure that you are in the `prouge_client` directory. Defaults to using port 3000 and host 127.0.0.1 (localhost), if you want to use something else, set `PROUGE_PORT` and/or `PROUGE_HOST` to some other value.

```
mix deps.get
mix run --no-halt
```

## The game

### Server

The server works by running multiple processes: One TCP server process, one game process and multiple client processes. The TCP server accepts TCP connections from clients, starts a client process (responsible for communicating with a single client) and hands over the connection to that newly created process. The game process holds and updates the game state. Whenever the game state is updated by a client, the new game state is sent to all connected clients.