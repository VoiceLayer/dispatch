Code.require_file("support/helper.exs", __DIR__)
Dispatch.Helper.setup_pubsub()
Task.Supervisor.start_link(name: Dispatch.TaskSupervisor)

ExUnit.start(capture_log: true)
