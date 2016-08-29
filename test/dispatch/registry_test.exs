defmodule Dispatch.RegistryTest do
  use ExUnit.Case, async: false
  alias Dispatch.{Registry, Helper}

  setup do
    type = "TypeForTests"
    pubsub_server = Application.get_env(:dispatch, :pubsub)
                      |> Keyword.get(:name, Dispatch.PubSub)
    Phoenix.PubSub.subscribe(pubsub_server, type)
    {:ok, _registry_pid} = Helper.setup_registry()
    on_exit fn ->
      Helper.clear_type(type)
    end
    {:ok, %{type: type}}
  end

  test "empty registry returns empty service list", %{type: type} do
    assert [] == Registry.get_services(type)
  end

  test "empty registry returns empty service list with a different type", %{type: type} do
    Registry.add_service("Other", self())
    assert [] == Registry.get_services(type)
    Helper.clear_type("Other")
  end

  test "enable service adds to registry", %{type: type} do
    Registry.add_service(type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}

    [{pid, %{node: node, state: state}}] = Registry.get_services(type)
    assert pid == this_pid
    assert node == this_node
    assert state == :online
  end

  test "enable service allows multiple different types", %{} do
    {:ok, service_1} = Agent.start(fn -> 1 end)
    {:ok, service_2} = Agent.start(fn -> 2 end)
    Registry.add_service("Type1", service_1)
    Registry.add_service("Type2", service_2)
    this_node = node()

    assert {:ok, ^this_node, ^service_1} = Registry.get_service("Type1", "my_key")
    assert {:ok, ^this_node, ^service_2} = Registry.get_service("Type2", "my_key")
  end

  test "remove service removes it from registry", %{type: type} do
    Registry.add_service(type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert {:ok, this_node, this_pid} == Registry.get_service(type, "key")

    Registry.remove_service(type, self())
    assert_receive {:leave, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    assert [] == Registry.get_services(type)
    assert {:error, :no_service_for_key} == Registry.get_service(type, "key")
  end

  test "disable service", %{type: type} do
    Registry.add_service(type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert {:ok, this_node, this_pid} == Registry.get_service(type, "key")

    Registry.disable_service(type, self())
    assert_receive {:leave, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :offline}}, 1_000

    [{pid, %{node: node, state: state}}] = Registry.get_services(type)
    assert pid == self
    assert node == node()
    assert state == :offline
    assert {:error, :no_service_for_key} == Registry.get_service(type, "key")

    Registry.enable_service(type, self())
    assert_receive {:leave, ^this_pid, %{node: ^this_node, state: :offline}}, 1_000
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert {:ok, this_node, this_pid} == Registry.get_service(type, "key")

  end

  test "enable multiple services", %{type: type} do
    Registry.add_service(type, self())
    other_pid = spawn(fn -> :timer.sleep(30_000) end)
    Registry.add_service(type, other_pid)

    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000
    assert_receive {:join, ^other_pid, %{node: ^this_node, state: :online}}, 1_000

    [{first_pid, %{node: ^this_node}}, {second_pid, %{node: ^this_node}}] = Registry.get_services(type)
    assert {first_pid, second_pid} == {this_pid, other_pid} or {second_pid, first_pid} == {this_pid, other_pid}
  end

  test "get online services", %{type: type}  do
    Registry.add_service(type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    [{pid, %{node: node, state: state}}] = Registry.get_online_services(type)
    assert pid == self
    assert node == node()
    assert state == :online
    Registry.disable_service(type, self())
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :offline}}, 1_000
    assert [] == Registry.get_online_services(type)
  end

  test "get error if no services joined", %{type: type}  do
    assert {:error, :no_service_for_key} == Registry.get_service(type, "my_key")
  end

  test "get service pid", %{type: type}  do
    Registry.add_service(type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    assert {:ok, this_node, this_pid} == Registry.get_service(type, "my_key")
  end

  test "get service pid from term key", %{type: type}  do
    Registry.add_service(type, self())
    {this_pid, this_node} = {self(), node()}
    assert_receive {:join, ^this_pid, %{node: ^this_node, state: :online}}, 1_000

    assert {:ok, this_node, this_pid} == Registry.get_service(type, {:abc, 1})
  end

end
