defmodule Dispatch do
  use Application
  require Logger

  def start(_type, _args) do
    case Code.ensure_compiled(:hash_ring) do
      {:module, _} -> Dispatch.Supervisor.start_link()
      _ ->
        message = ~s(Please add {:hash_ring, github: "voicelayer/hash-ring"} to your deps[])
        Logger.warn(message)
        raise message
    end
  end
end
