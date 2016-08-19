defmodule Dispatch.Supervisor do
  use Supervisor

  def start_link(_opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    children = [
      worker(:hash_ring, []),
    ]
    children = if Application.get_env(:dispatch, :test) do
      children
    else
      registry_name = Application.get_env(:dispatch, :registry, Dispatch.Registry)
      [worker(Dispatch.Registry, [[name: registry_name]]) | children]
    end

    supervise(children, strategy: :one_for_all)
  end
end
