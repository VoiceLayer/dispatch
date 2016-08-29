defmodule Dispatch.Mixfile do
  use Mix.Project

  def project do
    [app: :dispatch,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  def application do
    [applications: [:logger, :phoenix_pubsub],
      mod: {Dispatch, []}]
  end

  # Dependencies can be Hex packages:
  #
  defp deps do
    [
      {:hash_ring, github: "voicelayer/hash-ring"},
      {:phoenix_pubsub, "~> 1.0.0"}
    ]
  end
end
