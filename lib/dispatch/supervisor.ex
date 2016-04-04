defmodule Dispatch.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    pubsub = Application.get_env(:phoenix_pubsub, :pubsub)
    children = [
        worker(HashRing, [])
      ]

    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
    supervise([worker(HashRing, [])], strategy: :simple_one_for_one)
  end

  def start_hash_ring(supervisor, param) do
    Supervisor.start_child(supervisor, [param])
  end

  def stop_hash_ring(supervisor, child) do
    Supervisor.terminate_child(supervisor, child)
  end

end
