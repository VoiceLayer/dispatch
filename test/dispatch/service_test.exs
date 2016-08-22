defmodule Dispatch.ServiceTest do
  use ExUnit.Case, async: false
  alias Dispatch.{Service, Helper}

  defmodule FakeService do
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      :ok = Service.init(opts)
      {:ok, %{}}
    end

    def handle_call({:get, key}, _from, state) do
      {:reply, {:ok, key}, state}
    end

    def handle_cast({:set, key, from}, state) do
      send(from, {:set_request, key})
      {:noreply, state}
    end
  end

  setup do
    type = "TypeForServiceTest"
    [pubsub_server, _pubsub_opts] = Application.get_env(:phoenix_pubsub, :pubsub)
    Phoenix.PubSub.subscribe(pubsub_server, type)
    {:ok, _registry_pid} = Helper.setup_registry()
    on_exit fn ->
      Helper.clear_type(type)
    end
    {:ok, %{type: type}}
  end

  test "invoke service cast", %{type: type} do
    {:ok, service} = FakeService.start_link(type: type)
    this_node = node()
    assert_receive({:join, ^service, %{node: ^this_node, state: :online}})

    Service.cast(type, "my_key", {:set, "key", self()})
    assert_receive({:set_request, "key"})
  end

  test "invoke service call", %{type: type} do
    this_node = node()
    {:ok, service} = FakeService.start_link(type: type)
    assert_receive({:join, ^service, %{node: ^this_node, state: :online}})

    {:ok, result} = Service.call(type, "my_key", {:get, "my_key"})
    assert result == "my_key"
  end

  test "invoke service multi cast", %{type: type} do
    {:ok, service1} = FakeService.start_link(type: type)
    {:ok, service2} = FakeService.start_link(type: type)
    {:ok, service3} = FakeService.start_link(type: type)
    this_node = node()
    assert_receive({:join, ^service1, %{node: ^this_node, state: :online}})
    assert_receive({:join, ^service2, %{node: ^this_node, state: :online}})
    assert_receive({:join, ^service3, %{node: ^this_node, state: :online}})

    res = Service.multi_cast(2, type, "my_key", {:set, "key", self()})
    assert(res != {:error, :service_unavailable})
    assert_receive({:set_request, "key"})
    assert_receive({:set_request, "key"})
    # refute_receive(_)
  end

  test "invoke service multi call", %{type: type} do
    {:ok, service1} = FakeService.start_link(type: type)
    {:ok, service2} = FakeService.start_link(type: type)
    {:ok, service3} = FakeService.start_link(type: type)
    this_node = node()
    assert_receive({:join, ^service1, %{node: ^this_node, state: :online}})
    assert_receive({:join, ^service2, %{node: ^this_node, state: :online}})
    assert_receive({:join, ^service3, %{node: ^this_node, state: :online}})

    [{out_service1, out_res1}, {out_service2, out_res2}] = Service.multi_call(2, type, "my_key", {:get, "my_key"})
    assert(out_res1 == {:ok, "my_key"})
    assert(out_res2 == {:ok, "my_key"})
    assert(Enum.member?([service1, service2, service3], out_service1))
    assert(Enum.member?([service1, service2, service3], out_service2))
    assert(out_service1 != out_service2)
    # refute_receive(_)
  end

end
