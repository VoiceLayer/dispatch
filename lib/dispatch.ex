defmodule Dispatch do
  use Application

  def start(_type, _args) do
    Dispatch.Supervisor.start_link
  end

end
