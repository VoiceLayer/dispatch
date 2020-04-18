defmodule Dispatch.Registry do
  @moduledoc """
  Provides a distributes registry for services.

  This module implements the `Phoenix.Tracker` behaviour to provide a distributed
  registry of services. Services can be added and removed to and from the
  registry.

  Services are identified by their type. The type must be a binary.

  When a node goes down, all associated services will be removed from the
  registry when the CRDT syncs.

  A hash ring is used to determine which service to use for a particular
  term. The term is arbitrary, however the same node and service pid will
  always be returned for a term unless the number of services for the type
  changes.

  ## Optional

    * `:test` - If set to true then a registry and hashring will not be
      started when the application starts. They should be started manually
      with `Dispatch.Registry.start_link/1` and
      `Dispatch.Supervisor.start_hash_ring/2`. Defaults to `false`
  """

  @behaviour Phoenix.Tracker

  @doc """
  Start a new registry. The `pubsub` config value from `Dispatch` will be used.

  ## Examples

      iex> Dispatch.Registry.start_link()
      {:ok, #PID<0.168.0>}
  """
  def start_link(opts \\ []) do
    pubsub_server = Keyword.get(opts, :dispatch_name, Dispatch.PubSub)

    full_opts =
      Keyword.merge(
        [name: __MODULE__, pubsub_server: pubsub_server],
        opts
      )

    Phoenix.Tracker.start_link(__MODULE__, full_opts, full_opts)
  end

  @doc """
  Add a service to the registry. The service is set as online.

    * `type` - The type of the service. Must be a binary.
    * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.add_service("downloader", self())
      {:ok, "g20AAAAIlB7XfDdRhmk="}
  """
  def add_service(type, pid) do
    Phoenix.Tracker.track(__MODULE__, pid, type, pid, %{node: node(), state: :online})
  end

  @doc """
  Set a service as online. When a service is online it can be used.

  * `type` - The type of the service. Must be a binary.
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.enable_service("downloader", self())
      {:ok, "g20AAAAI9+IQ28ngDfM="}
  """
  def enable_service(type, pid) do
    Phoenix.Tracker.update(__MODULE__, pid, type, pid, %{node: node(), state: :online})
  end

  @doc """
  Set a service as offline. When a service is offline it can't be used.

  * `type` - The type of the service. Must be a binary.
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.disable_service("downloader", self())
      {:ok, "g20AAAAI4oU3ICYcsoQ="}
  """
  def disable_service(type, pid) do
    Phoenix.Tracker.update(__MODULE__, pid, type, pid, %{node: node(), state: :offline})
  end

  @doc """
  Remove a service from the registry.

  * `type` - The type of the service. Must be a binary.
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.remove_service("downloader", self())
      {:ok, "g20AAAAI4oU3ICYcsoQ="}
  """
  def remove_service(type, pid) do
    Phoenix.Tracker.untrack(__MODULE__, pid, type, pid)
  end

  @doc """
  List all of the services for a particular type.

  * `type` - The type of the service. Must be a binary.

  ## Examples

      iex> Dispatch.Registry.get_services("downloader")
      [{#PID<0.166.0>,
        %{node: :"slave2@127.0.0.1", phx_ref: "g20AAAAIHAHuxydO084=",
        phx_ref_prev: "g20AAAAI4oU3ICYcsoQ=", state: :online}}]
  """
  def get_services(type) do
    Phoenix.Tracker.list(__MODULE__, type)
  end

  @doc """
  List all of the services that are online for a particular type.

  * `type` - The type of the service. Must be a binary.

  ## Examples

      iex> Dispatch.Registry.get_online_services("downloader")
      [{#PID<0.166.0>,
        %{node: :"slave2@127.0.0.1", phx_ref: "g20AAAAIHAHuxydO084=",
        phx_ref_prev: "g20AAAAI4oU3ICYcsoQ=", state: :online}}]
  """
  def get_online_services(type) do
    get_services(type)
    |> Enum.filter(&(elem(&1, 1)[:state] == :online))
  end

  @doc """
  Find a service to use for a particular `key`

  * `type` - The type of the service. Must be a binary.
  * `key` - The key to lookup the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.find_service(:uploader, "file.png")
      {:ok, :"slave1@127.0.0.1", #PID<0.153.0>}
  """
  def find_service(type, key) do
    with(
      %HashRing{} = hash_ring <- GenServer.call(hash_ring_server(), {:get, type}),
      {:ok, service_info} <- HashRing.key_to_node(hash_ring, key),
      do: service_info
    )
    |> case do
      {host, pid} when is_pid(pid) -> {:ok, host, pid}
      _ -> {:error, :no_service_for_key}
    end
  end

  @doc """
  Find a list of `count` service instances to use for a particular `key`

  * `count` - The number of service instances to retrieve
  * `type` - The type of services to retrieve
  * `key` - The key to lookup the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.find_multi_service(2, :uploader, "file.png")
      [{:ok, :"slave1@127.0.0.1", #PID<0.153.0>}, {:ok, :"slave2@127.0.0.1", #PID<0.145.0>}]
  """
  def find_multi_service(count, type, key) do
    with(
      %HashRing{} = hash_ring <- GenServer.call(hash_ring_server(), {:get, type}),
      {:ok, service_info} <- HashRing.key_to_nodes(hash_ring, key, count),
      do: service_info
    )
    |> case do
      list when is_list(list) -> list
      _ -> []
    end
  end

  @doc false
  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server, hash_rings: %{}}}
  end

  @doc false
  def handle_diff(diff, state) do
    hash_rings = GenServer.call(hash_ring_server(), :get_all)

    hash_rings =
      Enum.reduce(diff, hash_rings, fn {type, _} = event, hash_rings ->
        hash_ring =
          hash_rings
          |> Map.get(type, HashRing.new())
          |> remove_leaves(event, state)
          |> add_joins(event, state)

        Map.put(hash_rings, type, hash_ring)
      end)

    GenServer.call(hash_ring_server(), {:put_all, hash_rings})
    {:ok, state}
  end

  defp remove_leaves(hash_ring, {type, {joins, leaves}}, state) do
    Enum.reduce(leaves, hash_ring, fn {pid, meta}, acc ->
      service_info = {meta.node, pid}

      any_joins =
        Enum.any?(joins, fn {jpid, %{state: meta_state}} ->
          jpid == pid && meta_state == :online
        end)

      Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, type, {:leave, pid, meta})

      case any_joins do
        true -> acc
        _ -> HashRing.remove_node(acc, service_info)
      end
    end)
  end

  defp add_joins(hash_ring, {type, {joins, _leaves}}, state) do
    Enum.reduce(joins, hash_ring, fn {pid, meta}, acc ->
      service_info = {meta.node, pid}
      Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, type, {:join, pid, meta})

      case meta.state do
        :online ->
          HashRing.add_node(acc, service_info)

        _ ->
          acc
      end
    end)
  end

  defp hash_ring_server() do
    Module.concat(__MODULE__, HashRing)
  end
end
