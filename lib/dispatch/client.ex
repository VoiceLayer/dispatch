defmodule Dispatch.Client do

  def cast(type, key, params) do
    registry_server = Application.get_env(:dispatch, :registry, Dispatch.Registry)
    case Dispatch.Registry.get_service_pid(registry_server, type, key) do
      {:ok, _node, pid} ->
        send pid, {:cast_request, key, params}
      _ -> {:error, :service_unavailable}
    end
  end

  def call(type, key, params) do
    registry_server = Application.get_env(:dispatch, :registry, Dispatch.Registry)
    timeout = Application.get_env(:dispatch, :timeout, 5000)
    case Dispatch.Registry.get_service_pid(registry_server, type, key) do
      {:ok, _node, pid} ->
        send pid, {:call_request, self, key, params}
        receive do 
          {:call_reply, reply} -> {:ok, reply}
          {:error, reason} -> {:error, reason}
        after
          timeout -> {:error, :timeout}
        end
      _ -> {:error, :service_unavailable}
    end
  end

end