# Dispatch

A distributed registry build on top of [phoenix_pubsub](https://github.com/phoenixframework/phoenix_pubsub).

## Installation

  1. Add dispatch to your list of dependencies in `mix.exs`:

        def deps do
          [{:dispatch, github: "voicelayer/dispatch"}]
        end

  2. Ensure dispatch is started before your application:

        def application do
          [applications: [:dispatch]]
        end

## Usage

### Configuration

Configure the registry:

```elixir
config :dispatch,
  timeout: 5_000,
  hashring: Dispatch.HashRing, # Prefix to use for HashRing registered name
  registry: Dispatch.Registry  # Name to assign to the registry
```

When the application is started, the registry with the configured name will
be started. A supervisor with the `hashring` name above will be started to
supervise each hash ring.

### Register a service

```elixir
iex> {:ok, service_pid} = Agent.start_link(fn _ -> 1 end) # Use your real service here
iex> Dispatch.Registry.add_service(Dispatch.Registry, :uploader, service_pid)
{:ok, "g20AAAAI9+IQ28ngDfM="}
```

In this example, `Dispatch.Registry` is the name that the registry pid has been
registered as. `:uploader` is the type of the service.

### Retrieve services

```elixir
iex> Dispatch.Registry.get_services(Dispatch.Registry, :uploader)
[{#PID<0.166.0>,
  %{node: :"slave2@127.0.0.1", phx_ref: "g20AAAAIHAHuxydO084=",
  phx_ref_prev: "g20AAAAI4oU3ICYcsoQ=", state: :online}}]
```

This retrieves all of the services.

### Finding a service for a key

```elixir
iex> Dispatch.Registry.get_service_pid(Dispatch.Registry, :uploader, "file.png")
{:ok, :"slave1@127.0.0.1", #PID<0.153.0>}
```

Using `get_service_pid/3` will return a tuple in the form `{:ok, node, pid}` where
`node` is the node that owns the `pid` that should be used. If no service can be
found then `{:error, reason}` will be returned.

## Convenience API

There are two modules that can be used. To register a service:

```elixir
Dispatch.Service.init(type: :uploader)
```

This will use the configuration name to attach a service to the configured registry
pid.

```elixir

# File is a map with the format %{name: "file.png", contents: "test file"} 
def upload(file)
  Dispatch.Client.cast(:uploader, file.name, {:upload, file})
end

def download(file)
  Dispatch.Client.call(:uploader, file.name, {:download, file})
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
