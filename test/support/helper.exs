defmodule Dispatch.Helper do
  import ExUnit.Assertions
  alias Dispatch.Registry

  @rtype "TestDispatchType"

  def setup_registry() do
    {:ok, registry_pid} = Registry.start_link([broadcast_period: 5_000,
                                               max_silent_periods: 20])
    if Process.whereis(Registry) do
      Process.unregister(Registry)
    end
    Process.register(registry_pid, Registry)
    {:ok, registry_pid}
  end

  def clear_type(type) do
    :hash_ring.delete_ring(type)
    if old_pid = Process.whereis(Registry) do
      Process.exit(old_pid, :kill)
    end
  end

  def wait_dispatch_ready(node \\ nil) do
    if node do
      assert_receive {:join, _, %{node: ^node, state: :online}}, 5_000
    else
      assert_receive {:join, _, %{node: _, state: :online}}, 5_000
    end
  end

  def get_online_services(type \\ @rtype) do
    Registry.get_services(Registry, type)
  end

end
