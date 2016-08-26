defmodule Dispatch.Supervisor do
  use Supervisor

  def start_link(_opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    registry_name = Application.get_env(:dispatch, :registry, Dispatch.Registry)
    pubsub = Application.get_env(:dispatch, :pubsub, [])

    children = [
      supervisor(pubsub[:adapter] || Phoenix.PubSub.PG2,
                 [pubsub[:name] || Phoenix.PubSub.Test.PubSub,
                  pubsub[:opts] || []]),
      worker(:hash_ring, []),
      worker(Dispatch.Registry, [[name: registry_name, log_level: :debug]]),
      supervisor(Task.Supervisor, [[name: TaskSupervisor]])
    ]

    supervise(children, strategy: :rest_for_one)
  end
end
