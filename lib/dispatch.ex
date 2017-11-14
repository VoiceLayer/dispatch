defmodule Dispatch do
  use Application
  require Logger

  def start(_type, _args) do
    Dispatch.Supervisor.start_link()
  end
end
