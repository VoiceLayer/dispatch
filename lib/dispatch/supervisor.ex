defmodule Dispatch.Supervisor do
  use Supervisor

  def start_link(_opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    pubsub = Application.get_env(:dispatch, :pubsub, [])
    opts = pubsub[:opts] || []
    opts = Keyword.put_new(opts, :name, Dispatch.PubSub)

    registry =
      Application.get_env(:dispatch, :registry, [])
      |> Keyword.put_new(:name, Dispatch.Registry)
      |> Keyword.put_new(:dispatch_name, Keyword.fetch!(opts, :name))


    children = [
      supervisor(Phoenix.PubSub.Supervisor, [opts]),
      worker(Dispatch.Registry, [registry]),
      worker(Dispatch.HashRingServer, [registry]),
      supervisor(Task.Supervisor, [[name: TaskSupervisor]])
    ]

    supervise(children, strategy: :rest_for_one)
  end
end
