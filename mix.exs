defmodule Dispatch.Mixfile do
  use Mix.Project

  @version "0.2.0"

  def project do
    [app: :dispatch,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     source_url: "https://github.com/VoiceLayer/dispatch",
     description: description(),
     package: package(),
     deps: deps(),
     docs: [extras: ["README.md"]]]
  end

  # Configuration for the OTP application
  #
  def application do
    [applications: [:logger, :phoenix_pubsub, :libring],
      mod: {Dispatch, []}]
  end

  # Dependencies can be Hex packages:
  #
  defp deps do
    [
      {:libring, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0.0"},
      {:ex_doc, "~> 0.13.0", only: :dev}
    ]
  end

  defp description do
    """
    A distributed service registry built on top of phoenix_pubsub.
    Requests are dispatched to one or more services based on hashed keys.
    """
  end

  defp package do
    [files: ~w(lib test mix.exs README.md LICENSE.md),
     maintainers: ["Gary Rennie", "Gabi Zuniga"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/voicelayer/dispatch",
              "Docs" => "http://hexdocs.pm/dispatch"}]
  end

end
