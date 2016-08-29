# Dispatch

[![Build Status](https://travis-ci.org/VoiceLayer/dispatch.svg?branch=master)](https://travis-ci.org/voicelayer/dispatch)

A distributed service registry built on top of [phoenix_pubsub](https://github.com/phoenixframework/phoenix_pubsub).

Requests are dispatched to one or more services based on hashed keys.

## Installation

  1. Add dispatch and hash_ring to your list of dependencies in `mix.exs`:

```elixir
        def deps do
          [
           {:hash_ring, github: "voicelayer/hash-ring"},
           {:dispatch, "~> 0.1.0"}]
        end
```

  2. Ensure dispatch is started before your application:

```elixir
        def application do
          [applications: [:dispatch]]
        end
```

## Usage

### Configuration

Configure the registry:

```elixir
config :dispatch,
  pubsub: [name: Phoenix.PubSub.Test.PubSub, 
           adapter: Phoenix.PubSub.PG2,
           opts: [pool_size: 1]]
```

When the application is started, a supervisor with be started supervising
a pubsub adapter with the name and options specified.

### Register a service

```elixir
iex> {:ok, service_pid} = Agent.start_link(fn _ -> 1 end) # Use your real service here
iex> Dispatch.Registry.add_service(:uploader, service_pid)
{:ok, "g20AAAAI9+IQ28ngDfM="}
```

In this example, :uploader` is the type of the service.

### Retrieve all services for a service type

```elixir
iex> Dispatch.Registry.get_services(:uploader)
[{#PID<0.166.0>,
  %{node: :"slave2@127.0.0.1", phx_ref: "g20AAAAIHAHuxydO084=",
  phx_ref_prev: "g20AAAAI4oU3ICYcsoQ=", state: :online}}]
```

This retrieves all of the services info.

### Finding a service for a key

```elixir
iex> Dispatch.Registry.find_service(:uploader, "file.png")
{:ok, :"slave1@127.0.0.1", #PID<0.153.0>}
```

Using `find_service/2` returns a tuple in the form `{:ok, node, pid}` where
`node` is the node that owns the service `pid`. If no service can be
found then `{:error, reason}` is returned.

### Finding a list of `count` service instances for a particular `key`

```elixir
iex> Dispatch.Registry.find_multi_service(2, :uploader, "file.png")
[{:ok, :"slave1@127.0.0.1", #PID<0.153.0>}, {:ok, :"slave2@127.0.0.1", #PID<0.145.0>}]
```

## Convenience API

The `Service` module can be used to automatically handle registration of a service 
based on a `GenServer`.

Call `Service.init` within your GenServer's `init` function.

```elixir
def init(_) do
  :ok = Dispatch.Service.init(type: :uploader)
  {:ok, %{}}
end
```

This will use the type provided to attach a service to the configured registry
pid.

Use `Dispatch.Service.cast` and `Dispatch.Service.call` to route the GenServer `cast` or `call`
to the appropriate service based on the `key` provided.

Use `Dispatch.Service.multi_cast` to send cast messages to several service instances at once.

`Dispatch.Service.multi_call` calls several service instances and waits
for all the responses before returning.

```elixir

# File is a map with the format %{name: "file.png", contents: "test file"} 
def upload(file)
  Dispatch.Service.cast(:uploader, file.name, {:upload, file})
end

def download(file)
  Dispatch.Service.call(:uploader, file.name, {:download, file})
end

def handle_cast({:upload, file}, state) do
  Logger.info("Uploading #{file.name}")
  {:noreply, Map.put(state, file.name, file.contents)}
end

def handle_call({:download, %{name: name}}, from, state) do
  Logger.info("Downloading #{name}")
  {:reply, {:ok, Map.get(state, name}}, state}
end
```

