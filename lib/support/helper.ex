defmodule Dispatch.Helper do
  import ExUnit.Assertions
  alias Dispatch.{Supervisor, Registry}

  def setup_dispatch() do
    [pubsub_server, _pubsub_opts] = Application.get_env(:phoenix_pubsub, :pubsub)

    type = Application.get_env(:dispatch, :type)
    Phoenix.PubSub.subscribe(pubsub_server, type)

    {:ok, hashring_pid} = Supervisor.start_hash_ring(Supervisor, [])
    hashring_server = Application.get_env(:dispatch, :hashring)
    Process.register(hashring_pid, hashring_server)

    registry_server = Application.get_env(:dispatch, :registry)
    {:ok, registry_pid} = Registry.start_link
    if old_pid = Process.whereis(registry_server) do
      Process.unregister(registry_server)
    end
    Process.register(registry_pid, registry_server)

    %{hashring_pid: hashring_pid, registry_pid: registry_pid, hashring: hashring_server, registry_server: registry_server, type: type}
  end

  def clean_dispatch(%{hashring_pid: hashring_pid, registry_pid: registry_pid}) do
    Supervisor.stop_hash_ring(Supervisor, hashring_pid)
  end

  def wait_dispatch_ready(node \\ nil) do
    if node do
      assert_receive {:join, _, %{node: ^node, state: :online}}, 5_000
    else
      assert_receive {:join, _, %{node: _, state: :online}}, 5_000
    end
  end

  def get_online_services() do
    registry_server = Application.get_env(:dispatch, :registry)
    type = Application.get_env(:dispatch, :type)    
    Registry.get_services(registry_server, type)
  end

end