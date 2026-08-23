defmodule Mold.MixProject do
  use Mix.Project
  @version "0.2.0"
  @source_url "https://github.com/fuelen/mold"

  def project do
    [
      app: :mold,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Mold",
      description: "A tiny, zero-dependency parsing library for external payloads",
      package: package(),
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      docs: [
        main: "Mold",
        source_ref: "v#{@version}",
        extras: [
          "cheatsheet.cheatmd",
          "guides/formatting-errors.md",
          "guides/using-with-http-clients.md",
          "CHANGELOG.md"
        ],
        groups_for_docs: [
          "Types: Basic": &(&1[:group] == "Types: Basic"),
          "Types: Date & Time": &(&1[:group] == "Types: Date & Time"),
          "Types: Collections": &(&1[:group] == "Types: Collections"),
          "Types: Composite": &(&1[:group] == "Types: Composite"),
          "Types: Custom": &(&1[:group] == "Types: Custom")
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files:
        ~w(lib guides .formatter.exs mix.exs README.md LICENSE.txt CHANGELOG.md cheatsheet.cheatmd)
    ]
  end
end
