defmodule Dispatch.Registry do
  @behaviour Phoenix.Tracker

  def start_link(opts \\ []) do
    [pubsub_server, pubsub_opts] = Application.get_env(:phoenix_pubsub, :pubsub)
    opts = Keyword.merge([name: __MODULE__, 
                          pubsub_server: pubsub_server],
                         opts)

    # this needs to move to a Supervisor
    GenServer.start_link(Phoenix.Tracker, [__MODULE__, opts, opts], [])
  end

  def start_service(server, type, pid) do
    # might need to convert pid to term using :erlang.term_to_binary(pid)
    Phoenix.Tracker.track(server, pid, type, pid, %{node: node(), state: :online})
  end

  def enable_service(server, type, pid) do
    Phoenix.Tracker.update(server, pid, type, pid, %{node: node(), state: :online})
  end

  def disable_service(server, type, pid) do
    Phoenix.Tracker.update(server, pid, type, pid, %{node: node(), state: :offline})
  end

  def remove_service(server, type, pid) do
    Phoenix.Tracker.untrack(server, pid, type, pid)
  end

  def get_services(server, type) do
    Phoenix.Tracker.list(server, type)
  end

  def get_online_services(server, type) do
    server
      |> get_services(type) 
      |> Enum.filter(&(elem(&1, 1)[:state] == :online))
  end

  def get_service_pid(server, type, key) do
    case HashRing.find(Dispatch.HashRing, key) do
      {:ok, service_info} ->
        {node, pid} = service_info |> :erlang.binary_to_term
        {:ok, node, pid}
      _ -> {:error}
    end
  end

  # Phoenix Tracker Behavior

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    hashring_server = Application.get_env(:dispatch, :hashring)
    {:ok, %{pubsub_server: server, 
            node_name: Phoenix.PubSub.node_name(server),
            hashring_server: hashring_server}}
  end

  def handle_diff(diff, state) do
    # IO.puts "diff = #{inspect diff}, state = #{inspect diff}"
    for {topic, {joins, leaves}} <- diff do
      for {pid, meta} <- joins do
        service_info = {meta.node, pid}
        case meta.state do
          :online ->
            HashRing.add(state.hashring_server, service_info |> :erlang.term_to_binary)
          :offline ->
            HashRing.drop(state.hashring_server, service_info |> :erlang.term_to_binary)
        end

        # IO.puts "presence join: key \"#{inspect key}\" with meta #{inspect meta}"
        Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, topic, {:join, pid, meta})
      end
      for {pid, meta} <- leaves do
        # IO.puts "presence leave: key \"#{inspect key}\" with meta #{inspect meta}"
        service_info = {meta.node, pid}
        HashRing.drop(state.hashring_server, service_info |> :erlang.term_to_binary)
        Phoenix.PubSub.direct_broadcast(node(), state.pubsub_server, topic, {:leave, pid, meta})
      end
    end
    {:ok, state}
  end

end