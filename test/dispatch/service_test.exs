defmodule Dispatch.ServiceTest do
  use ExUnit.Case, async: false
  alias Dispatch.{Service, Client, Helper}

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

    Client.cast(type, "my_key", {:set, "key", self()})
    assert_receive({:set_request, "key"})
  end

  test "invoke service call", %{type: type} do
    this_node = node()
    {:ok, service} = FakeService.start_link(type: type)
    assert_receive({:join, ^service, %{node: ^this_node, state: :online}})

    {:ok, result} = Client.call(type, "my_key", {:get, "my_key"})
    assert result == "my_key"
  end

end
