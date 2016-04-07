defmodule Dispatch.ServiceTest do
  use ExUnit.Case, async: false
  alias Dispatch.{Service, Client, Helper}

  setup do
    ctx = Helper.setup_dispatch()
    on_exit fn ->
      Helper.clean_dispatch(ctx)
    end
    {:ok, ctx}
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