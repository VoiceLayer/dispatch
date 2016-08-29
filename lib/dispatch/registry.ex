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
    pubsub_server = Application.get_env(:dispatch, :pubsub)
                      |> Keyword.get(:name, Dispatch.PubSub)
    full_opts = Keyword.merge([name: __MODULE__,
                          pubsub_server: pubsub_server],
                         opts)
    GenServer.start_link(Phoenix.Tracker, [__MODULE__, full_opts, full_opts], opts)
  end

  @doc """
  Add a service to the registry. The service is set as online.

    * `type` - The type of the service. Can be any elixir term
    * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.add_service(:downloader, self())
      {:ok, "g20AAAAIlB7XfDdRhmk="}
  """
  def add_service(type, pid) do
    Phoenix.Tracker.track(__MODULE__, pid, type, pid, %{node: node(), state: :online})
  end

  @doc """
  Set a service as online. When a service is online it can be used.

  * `type` - The type of the service. Can be any elixir term
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.enable_service(:downloader, self())
      {:ok, "g20AAAAI9+IQ28ngDfM="}
  """
  def enable_service(type, pid) do
    Phoenix.Tracker.update(__MODULE__, pid, type, pid, %{node: node(), state: :online})
  end

  @doc """
  Set a service as offline. When a service is offline it can't be used.

  * `type` - The type of the service. Can be any elixir term
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.disable_service(:downloader, self())
      {:ok, "g20AAAAI4oU3ICYcsoQ="}
  """
  def disable_service(type, pid) do
    Phoenix.Tracker.update(__MODULE__, pid, type, pid, %{node: node(), state: :offline})
  end

  @doc """
  Remove a service from the registry.

  * `type` - The type of the service. Can be any elixir term
  * `pid` - The pid that provides the service

  ## Examples

      iex> Dispatch.Registry.remove_service(:downloader, self())
      {:ok, "g20AAAAI4oU3ICYcsoQ="}
  """
  def remove_service(type, pid) do
    Phoenix.Tracker.untrack(__MODULE__, pid, type, pid)
  end

  @doc """
  List all of the services for a particular type.

  * `type` - The type of the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.get_services(:downloader)
      [{#PID<0.166.0>,
        %{node: :"slave2@127.0.0.1", phx_ref: "g20AAAAIHAHuxydO084=",
        phx_ref_prev: "g20AAAAI4oU3ICYcsoQ=", state: :online}}]
  """
  def get_services(type) do
    Phoenix.Tracker.list(__MODULE__, type)
  end

  @doc """
  List all of the services that are online for a particular type.

  * `type` - The type of the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.get_online_services(:downloader)
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

  * `type` - The type of service to retrieve
  * `key` - The key to lookup the service. Can be any elixir term

  ## Examples

      iex> Dispatch.Registry.find_service(:uploader, "file.png")
      {:ok, :"slave1@127.0.0.1", #PID<0.153.0>}
  """
  def find_service(type, key) do
    with({:ok, service_info} <- :hash_ring.find_node(type, :erlang.term_to_binary(key)),
              do: :erlang.binary_to_term(service_info))
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
    with({:ok, service_info_list} <- :hash_ring.get_nodes(type, :erlang.term_to_binary(key), count),
      do: Enum.map(service_info_list, &:erlang.binary_to_term/1))
    |> case do
      list when is_list(list) -> list
      _ -> []
    end
  end


  @doc false
  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server}}
  end

  @doc false
  def handle_diff(diff, state) do
    for {type, {joins, leaves}} <- diff do
      unless :hash_ring.has_ring(type) do
        :ok = :hash_ring.create_ring(type, 128)
      end
      for {pid, meta} <- leaves do
        service_info = :erlang.term_to_binary({meta.node, pid})
        unless Enum.any?(joins,
                         fn({jpid, %{state: meta_state}}) -> jpid == pid && meta_state == :online end) do
          :hash_ring.remove_node(type, service_info)
        end
        Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, type, {:leave, pid, meta})
      end
      for {pid, meta} <- joins do
        service_info = :erlang.term_to_binary({meta.node, pid})
        case meta.state do
          :online ->
            :hash_ring.add_node(type, service_info)
          _ -> :ok
        end

        Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, type, {:join, pid, meta})
      end
    end
    {:ok, state}
  end
end
