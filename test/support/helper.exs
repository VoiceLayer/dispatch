defmodule Dispatch.Helper do
  import ExUnit.Assertions
  alias Dispatch.Registry

  @rtype "TestDispatchType"

  def setup_pubsub() do
    pubsub = Application.get_env(:dispatch, :pubsub, [])
    opts = pubsub[:opts] || []
    opts = Keyword.put_new(opts, :name, Phoenix.PubSub.Test.PubSub)

    Phoenix.PubSub.Supervisor.start_link(opts)
  end

  def setup_registry() do
    pubsub = Application.get_env(:dispatch, :pubsub, [])
    opts = pubsub[:opts] || []
    name = Keyword.get(opts, :name, Phoenix.PubSub.Test.PubSub)
    {:ok, registry_pid} =
      Registry.start_link(
        broadcast_period: 5_000,
        max_silent_periods: 20,
        name: Registry,
        dispatch_name: name
      )

    {:ok, _} = Dispatch.HashRingServer.start_link(name: Registry)
    {:ok, registry_pid}
  end

  def clear_type(_type) do
    if old_pid = Process.whereis(Registry) do
      Supervisor.stop(old_pid)
    end
  catch
    :exit, _ -> nil
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
