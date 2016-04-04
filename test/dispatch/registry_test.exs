defmodule Dispatch.RegistryTest do
  use ExUnit.Case, async: false
  alias Dispatch.Registry
  alias Phoenix.PubSub

  setup do
    hashring_server = Application.get_env(:dispatch, :hashring)
    {:ok, hashring_pid} = Dispatch.Supervisor.start_hash_ring(Dispatch.Supervisor, [])
    Process.register(hashring_pid, hashring_server)
    on_exit fn ->
      Dispatch.Supervisor.stop_hash_ring(Dispatch.Supervisor, hashring_pid)
    end

    type = Application.get_env(:dispatch, :type)
    [pubsub_server, pubsub_opts] = Application.get_env(:phoenix_pubsub, :pubsub)

    {:ok, registry_pid} = Registry.start_link
    PubSub.subscribe(pubsub_server, type)

    {:ok, %{registry: registry_pid, hashring: hashring_server, type: type}}
  end

  test "empty registry returns empty service list", %{registry: registry, type: type} do
    assert [] == Registry.get_services(registry, type)
  end

  test "enable service adds to registry", %{registry: registry, type: type} do
    Registry.start_service(registry, type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}

    [{pid, %{node: node, state: state}}] = Registry.get_services(registry, type)
    assert pid == this_pid
    assert node == this_node
    assert state == :online
  end

  test "remove service removes it from registry", %{registry: registry, type: type} do
    Registry.start_service(registry, type, self())
    Registry.remove_service(registry, type, self())

    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:leave, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    assert [] == Registry.get_services(registry, type)
  end

  test "disable service", %{registry: registry, type: type} do
    Registry.start_service(registry, type, self())
    Registry.disable_service(registry, type, self())

    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :offline}}, 1_000

    [{pid, %{node: node, state: state}}] = Registry.get_services(registry, type)
    assert pid == self
    assert node == node()
    assert state == :offline
  end

  test "enable multiple services", %{registry: registry, type: type} do
    Registry.start_service(registry, type, self())
    other_pid = spawn(fn -> :timer.sleep(30_000) end)
    Registry.start_service(registry, type, other_pid)

    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:join, ^other_pid, %{node: ^this_node, state: :online}}, 1_000

    [{first_pid, %{node: ^this_node}}, {second_pid, %{node: ^this_node}}] = Registry.get_services(registry, type)
    assert {first_pid, second_pid} == {this_pid, other_pid} or {second_pid, first_pid} == {this_pid, other_pid}
  end

  test "get online services", %{registry: registry, type: type}  do
    Registry.start_service(registry, type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    [{pid, %{node: node, state: state}}] = Registry.get_online_services(registry, type)
    assert pid == self
    assert node == node()
    assert state == :online
    
    Registry.disable_service(registry, type, self())
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :offline}}, 1_000
    assert [] == Registry.get_online_services(registry, type)
  end

  test "get error if no services joined", %{registry: registry, type: type}  do
    IO.puts "#{Registry.get_online_services(registry, type)}"
    assert {:error} == Registry.get_service_pid(registry, type, "my_key")
  end

  test "get service pid", %{registry: registry, type: type}  do
    Registry.start_service(registry, type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    assert {:ok, this_node, this_pid} == Registry.get_service_pid(registry, type, "my_key")
  end
end
