defmodule Tidy.MixProject do
  use Mix.Project

  @version "0.1.2"

  def project do
    [
      app: :tidy,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Checks documentation and specs of Elixir modules.",
      docs: docs()
    ]
  end

  defp docs do
    [
      main: "Tidy",
      canonical: "http://hexdocs.pm/tidy",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/IanLuites/tidy",
      groups_for_modules: [
        Adapters: [
          Tidy.Checks.ModuleDoc,
          Tidy.Checks.FunctionDoc,
          Tidy.Checks.FunctionSpec
        ]
      ]
    ]
  end

  defp package do
    [
      name: :tidy,
      maintainers: ["Ian Luites"],
      licenses: ["MIT"],
      files: ~w(.formatter.exs mix.exs README.md LICENSE lib),
      links: %{github: "https://github.com/IanLuites/tidy"}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev}]
  end
end
