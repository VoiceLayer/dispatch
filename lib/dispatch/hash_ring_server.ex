defmodule Dispatch.HashRingServer do
  @moduledoc false

  def start_link(opts \\ []) do
    name = Keyword.fetch!(opts, :name)
    opts = [name: Module.concat(name, HashRing)]
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc false
  def init(_) do
    {:ok, %{hash_rings: %{}}}
  end

  def handle_call({:get, type}, _reply, state) do
    {:reply, Map.get(state.hash_rings, type, {:error, :no_nodes}), state}
  end

  def handle_call(:get_all, _reply, state) do
     {:reply, state.hash_rings, state}
  end

  def handle_call({:put_all, hash_rings}, _reply, state) do
    {:reply, :ok, %{state | hash_rings: hash_rings}}
  end
end
