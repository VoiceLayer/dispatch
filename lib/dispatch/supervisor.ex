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
      {Phoenix.PubSub.Supervisor, opts},
      {Dispatch.Registry, registry},
      {Dispatch.HashRingServer, registry},
      {Task.Supervisor, [name: Dispatch.TaskSupervisor]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
