defmodule Dispatch.Service do
  def init(opts) do
    type = Keyword.fetch!(opts, :type)
    server = Application.get_env(:dispatch, :registry, Dispatch.Registry)
    case Dispatch.Registry.add_service(server, type, self) do
      {:ok, _} -> :ok
      other -> other
    end
  end
end
