defmodule Dispatch.Service do
  alias Dispatch.Registry

  def init(opts) do
    type = Keyword.fetch!(opts, :type)

    case Registry.add_service(type, self()) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def cast(type, key, params) do
    case Registry.find_service(type, key) do
      {:ok, _node, pid} -> GenServer.cast(pid, params)
      _ -> {:error, :service_unavailable}
    end
  end

  def call(type, key, params, timeout \\ 5000) do
    case Registry.find_service(type, key) do
      {:ok, _node, pid} -> GenServer.call(pid, params, timeout)
      _ -> {:error, :service_unavailable}
    end
  end

  def multi_cast(count, type, key, params) do
    case Registry.find_multi_service(count, type, key) do
      [] ->
        {:error, :service_unavailable}

      servers ->
        servers
        |> Enum.each(fn {_node, pid} ->
          GenServer.cast(pid, params)
        end)

        {:ok, Enum.count(servers)}
    end
  end

  def multi_call(count, type, key, params, timeout \\ 5000) do
    case Registry.find_multi_service(count, type, key) do
      [] ->
        {:error, :service_unavailable}

      servers ->
        for {_node, pid} <- servers do
          Task.Supervisor.async_nolink(Dispatch.TaskSupervisor, fn ->
            try do
              {:ok, pid, GenServer.call(pid, params, timeout)}
            catch
              :exit, reason -> {:error, pid, reason}
            end
          end)
        end
        |> Enum.map(&Task.await(&1, :infinity))
    end
  end
end
