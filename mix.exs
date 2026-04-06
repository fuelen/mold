defmodule Mold.MixProject do
  use Mix.Project
  @version "0.1.0"
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
      docs: [
        main: "Mold",
        source_ref: "v#{@version}",
        extras: ["cheatsheet.cheatmd"],
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
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.txt cheatsheet.cheatmd)
    ]
  end
end
