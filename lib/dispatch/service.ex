defmodule Dispatch.Service do

  def init(opts) do
    type = Keyword.fetch!(opts, :type)
    server = Application.get_env(:dispatch, :registry, Dispatch.Registry)
    case Dispatch.Registry.start_service(server, type, self) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def reply(to, reply) do
    send to, {:call_reply, reply}    
  end

end