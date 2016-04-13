use Mix.Config

config :dispatch,
  timeout: 5_000,
  hashring: Dispatch.HashRing,
  registry: Dispatch.Registry

import_config "#{Mix.env}.exs"
