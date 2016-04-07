defmodule Dispatch.RegistryTest do
  use ExUnit.Case, async: false
  alias Dispatch.{Registry, Helper}

  setup do
    ctx = Helper.setup_dispatch()
    on_exit fn ->
      Helper.clean_dispatch(ctx)
    end
    {:ok, ctx}
  end

  test "empty registry returns empty service list", %{registry_pid: registry_pid, type: type} do
    assert [] == Registry.get_services(registry_pid, type)
  end

  test "enable service adds to registry", %{registry_pid: registry_pid, type: type} do
    Registry.start_service(registry_pid, type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}

    [{pid, %{node: node, state: state}}] = Registry.get_services(registry_pid, type)
    assert pid == this_pid
    assert node == this_node
    assert state == :online
  end

  test "remove service removes it from registry", %{registry_pid: registry_pid, type: type} do
    Registry.start_service(registry_pid, type, self())
    Registry.remove_service(registry_pid, type, self())

    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:leave, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    assert [] == Registry.get_services(registry_pid, type)
  end

  test "disable service", %{registry_pid: registry_pid, type: type} do
    Registry.start_service(registry_pid, type, self())
    Registry.disable_service(registry_pid, type, self())

    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :offline}}, 1_000

    [{pid, %{node: node, state: state}}] = Registry.get_services(registry_pid, type)
    assert pid == self
    assert node == node()
    assert state == :offline
  end

  test "enable multiple services", %{registry_pid: registry_pid, type: type} do
    Registry.start_service(registry_pid, type, self())
    other_pid = spawn(fn -> :timer.sleep(30_000) end)
    Registry.start_service(registry_pid, type, other_pid)

    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:join, ^other_pid, %{node: ^this_node, state: :online}}, 1_000

    [{first_pid, %{node: ^this_node}}, {second_pid, %{node: ^this_node}}] = Registry.get_services(registry_pid, type)
    assert {first_pid, second_pid} == {this_pid, other_pid} or {second_pid, first_pid} == {this_pid, other_pid}
  end

  test "get online services", %{registry_pid: registry_pid, type: type}  do
    Registry.start_service(registry_pid, type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    [{pid, %{node: node, state: state}}] = Registry.get_online_services(registry_pid, type)
    assert pid == self
    assert node == node()
    assert state == :online
    
    Registry.disable_service(registry_pid, type, self())
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :offline}}, 1_000
    assert [] == Registry.get_online_services(registry_pid, type)
  end

  test "get error if no services joined", %{registry_pid: registry_pid, type: type}  do
    IO.puts "#{Registry.get_online_services(registry_pid, type)}"
    assert {:error} == Registry.get_service_pid(registry_pid, type, "my_key")
  end

  test "get service pid", %{registry_pid: registry_pid, type: type}  do
    Registry.start_service(registry_pid, type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    assert {:ok, this_node, this_pid} == Registry.get_service_pid(registry_pid, type, "my_key")
  end
end
