defmodule Dispatch.Supervisor do
  use Supervisor

  def start_link(_opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def init(:ok) do
    registry =
      Application.get_env(:dispatch, :registry, [])
      |> Keyword.put_new(:name, Dispatch.Registry)


    pubsub = Application.get_env(:dispatch, :pubsub, [])

    children = [
      supervisor(pubsub[:adapter] || Phoenix.PubSub.PG2,
                 [pubsub[:name] || Phoenix.PubSub.Test.PubSub,
                  pubsub[:opts] || []]),
      worker(Dispatch.Registry, [registry]),
      worker(Dispatch.HashRingServer, [registry]),
      supervisor(Task.Supervisor, [[name: TaskSupervisor]])
    ]

    supervise(children, strategy: :rest_for_one)
  end
end
