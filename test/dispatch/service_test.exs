defmodule Dispatch.ServiceTest do
  use ExUnit.Case, async: false
  alias Dispatch.{Registry, Service, Client, Supervisor}
  alias Phoenix.PubSub

  setup do
    hashring_server = Application.get_env(:dispatch, :hashring)
    {:ok, hashring_pid} = Supervisor.start_hash_ring(Supervisor, [])
    Process.register(hashring_pid, hashring_server)
    on_exit fn ->
      Supervisor.stop_hash_ring(Supervisor, hashring_pid)
    end

    type = Application.get_env(:dispatch, :type)
    [pubsub_server, _pubsub_opts] = Application.get_env(:phoenix_pubsub, :pubsub)

    {:ok, registry_pid} = Registry.start_link

    registry_server = Application.get_env(:dispatch, :registry)
    Process.register(registry_pid, registry_server)
    PubSub.subscribe(pubsub_server, type)

    {:ok, %{type: type}}
  end

  test "invoke service cast", %{type: type} do
    :ok = Service.init([type: type])
    this_pid = self()
    this_node = node()
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}

    Client.cast(type, "my_key", ["param"])
    assert_receive {:cast_request, "my_key", ["param"]}
  end

  test "invoke service call", %{type: type} do
    this_node = node()

    task = Task.async(fn -> 
      Service.init([type: type]) 
      receive do 
        {:call_request, from, key, params} ->
          Service.reply(from, {key, params})
      end
    end)

    task_pid = task.pid
    assert_receive {:join, ^task_pid, %{node: ^this_node, state: :online}}, 5_000

    {state, result} = Client.call(type, "my_key", ["param"])
    assert state == :ok
    assert result == {"my_key", ["param"]}
  end

end