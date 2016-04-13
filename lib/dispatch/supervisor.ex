defmodule Dispatch.Supervisor do
  use Supervisor

  def start_link(_opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    if Application.get_env(:dispatch, :test) do
      children = [
          worker(HashRing, [])
        ]

      supervise(children, strategy: :simple_one_for_one)
    else
      registry_name = Application.get_env(:dispatch, :registry, Dispatch.Registry)
      hashring_name = Application.get_env(:dispatch, :hashring, Dispatch.HashRing)
      children = [
          worker(Dispatch.Registry, [[name: registry_name]]),
          worker(HashRing, [[name: hashring_name]])
        ]

      supervise(children, strategy: :one_for_one)
    end    
  end

  def start_hash_ring(supervisor, param) do
    Supervisor.start_child(supervisor, [param])
  end

  def stop_hash_ring(supervisor, child) do
    Supervisor.terminate_child(supervisor, child)
  end

end
