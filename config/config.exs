use Mix.Config

config :dispatch,
  type: "DispatchService",
  timeout: 5_000,
  hashring: Dispatch.HashRing,
  registry: Dispatch.Registry

import_config "#{Mix.env}.exs"
