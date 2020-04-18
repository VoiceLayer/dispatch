use Mix.Config

if Mix.env == :test do
  config :dispatch,
    pubsub: [name: Phoenix.PubSub.Test.PubSub, adapter: Phoenix.PubSub.PG2, opts: [pool_size: 1]]
end
