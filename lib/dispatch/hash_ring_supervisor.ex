defmodule Dispatch.HashRingSupervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      worker(HashRing, []),
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_hash_ring(supervisor, param) do
    Supervisor.start_child(supervisor, [param])
  end

  def stop_hash_ring(supervisor, child) do
    Supervisor.terminate_child(supervisor, child)
  end
end
