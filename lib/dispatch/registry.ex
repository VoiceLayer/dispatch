defmodule Dispatch.Registry do
  @moduledoc """
  Provides a distributes registry for services.

  This module implements the `Phoenix.Tracker` behaviour to provide a distributed
  registry of services. Services can be added and removed to and from the
  registry.

  Services are identified by their type. The type can be any valid Elixir term,
  such as an atom or string.

  When a node goes down, all associated services will be removed from the
  registry when the CRDT syncs.

  A hash ring is used to determine which service to use for a particular
  term. The term is arbitrary, however the same node and service pid will
  always be returned for a term unless the number of services for the type
  changes.

  ## Optional

    * `:registry` - The name of the registry. Defaults to `Dispatch.Registry`
    * `:hashring` - The name of the hashring. Defaults to `Dispatch.HashRing`
    * `:test` - If set to true then a registry and hashring will not be
      started when the application starts. They should be started manually
      with `Dispatch.Registry.start_link/1` and
      `Dispatch.Supervisor.start_hash_ring/2`. Defaults to `false`
  """

  @behaviour Phoenix.Tracker

  @doc """
  Start a new registry. Unless overridden, the `pubsub` config value from
  `phoenix_pubsub` will be used.

  The `name` option will default to `Dispatch.Registry` and can be overridden
  with the `name` option.

  ## Examples

      iex> Dispatch.Registry.start_link()
      {:ok, #PID<0.168.0>}
  """
  def start_link(opts \\ []) do
    [pubsub_server, _pubsub_opts] = Application.get_env(:phoenix_pubsub, :pubsub)
    full_opts = Keyword.merge([name: __MODULE__,
                          pubsub_server: pubsub_server],
                         opts)
    GenServer.start_link(Phoenix.Tracker, [__MODULE__, full_opts, full_opts], opts)
  end

  @doc """
  Add a service to the registry. The service is set as online.

    * `server` - The pid or named pid for the registry
    * `type` - The type of the service. Can be any elixir term
    * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.add_service(Dispatch.Registry, :downloader, self())
      {:ok, "g20AAAAIlB7XfDdRhmk="}
  """
  def add_service(server, type, pid) do
    Phoenix.Tracker.track(server, pid, type, pid, %{node: node(), state: :online})
  end

  @doc """
  Set a service as online. When a service is online it can be used.

  * `server` - The pid or named pid for the registry
  * `type` - The type of the service. Can be any elixir term
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.enable_service(Dispatch.Registry, :downloader, self())
      {:ok, "g20AAAAI9+IQ28ngDfM="}
  """
  def enable_service(server, type, pid) do
    Phoenix.Tracker.update(server, pid, type, pid, %{node: node(), state: :online})
  end

  @doc """
  Set a service as offline. When a service is offline it can't be used.

  * `server` - The pid or named pid for the registry
  * `type` - The type of the service. Can be any elixir term
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.disable_service(Dispatch.Registry, :downloader, self())
      {:ok, "g20AAAAI4oU3ICYcsoQ="}
  """
  def disable_service(server, type, pid) do
    Phoenix.Tracker.update(server, pid, type, pid, %{node: node(), state: :offline})
  end

  @doc """
  Remove a service from the registry.

  * `server` - The pid or named pid for the registry
  * `type` - The type of the service. Can be any elixir term
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.remove_service(Dispatch.Registry, :downloader, self())
      {:ok, "g20AAAAI4oU3ICYcsoQ="}
  """
  def remove_service(server, type, pid) do
    Phoenix.Tracker.untrack(server, pid, type, pid)
  end

  @doc """
  List all of the services for a particular type.

  * `server` - The pid or named pid for the registry
  * `type` - The type of the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.get_services(Dispatch.Registry, :downloader)
      [{#PID<0.166.0>,
        %{node: :"slave2@127.0.0.1", phx_ref: "g20AAAAIHAHuxydO084=",
        phx_ref_prev: "g20AAAAI4oU3ICYcsoQ=", state: :online}}]
  """
  def get_services(server, type) do
    Phoenix.Tracker.list(server, type)
  end

  @doc """
  List all of the services that are online for a particular type.

  * `server` - The pid or named pid for the registry
  * `type` - The type of the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.get_online_services(Dispatch.Registry, :downloader)
      [{#PID<0.166.0>,
        %{node: :"slave2@127.0.0.1", phx_ref: "g20AAAAIHAHuxydO084=",
        phx_ref_prev: "g20AAAAI4oU3ICYcsoQ=", state: :online}}]
  """
  def get_online_services(server, type) do
    server
      |> get_services(type)
      |> Enum.filter(&(elem(&1, 1)[:state] == :online))
  end

  @doc """
  Get a service pid to use for a particular `key`

  * `server` - Not currently used
  * `type` - The type of service to retrieve
  * `key` - The key to lookup the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.get_service_pid(Dispatch.Registry, :uploader, "file.png")
      {:ok, :"slave1@127.0.0.1", #PID<0.153.0>}
  """
  def get_service_pid(_server, type, key) do
    hashring_server =
      Application.get_env(:dispatch, :hashring, Dispatch.HashRing)
      |> Module.concat(type)

      service = with pid when is_pid(pid) <- Process.whereis(hashring_server),
               {:ok, service_info}  <- HashRing.find(hashring_server, key),
               do: :erlang.binary_to_term(service_info)

    case service do
      {host, pid} when is_pid(pid) -> {:ok, host, pid}
      _ -> {:error, :no_service_for_key}
    end
  end

  @doc false
  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    hashring_server = Application.get_env(:dispatch, :hashring, Dispatch.HashRing)
    {:ok, %{pubsub_server: server,
            node_name: Phoenix.PubSub.node_name(server),
            hashring_server: hashring_server}}
  end

  @doc false
  def handle_diff(diff, state) do
    for {type, {joins, leaves}} <- diff do
      hashring_server = Module.concat(state.hashring_server, type)
      case Process.whereis(hashring_server) do
        pid when is_pid(pid) -> pid
        _                    ->
          {:ok, pid} = Dispatch.HashRingSupervisor.start_hash_ring(state.hashring_server, [name: hashring_server])
      end
      for {pid, meta} <- joins do
        service_info = {meta.node, pid}
        case meta.state do
          :online ->
            HashRing.add(hashring_server, service_info |> :erlang.term_to_binary)
          :offline ->
            HashRing.drop(hashring_server, service_info |> :erlang.term_to_binary)
        end

        Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, type, {:join, pid, meta})
      end
      for {pid, meta} <- leaves do
        service_info = {meta.node, pid}
        HashRing.drop(hashring_server, service_info |> :erlang.term_to_binary)
        Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, type, {:leave, pid, meta})
      end
    end
    {:ok, state}
  end
end
