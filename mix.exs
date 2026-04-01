defmodule PyreWeb.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/chrislaskey/pyre_web"

  def project do
    [
      app: :pyre_web,
      version: @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Web interface for Pyre (github.com/chrislaskey/pyre)",
      package: package(),
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:pyre, path: "../pyre_core", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end
end
