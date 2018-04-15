defmodule Mix.Tasks.Tidy do
  use Mix.Task

  @shortdoc "Run tidy analysis."
  @moduledoc @shortdoc

  @doc false
  def run(_argv) do
    Mix.Task.run("compile")

    app =
      ~r/app: *:(?<app>[a-z\_]+)/
      |> Regex.named_captures(File.read!("./mix.exs"))
      |> Map.get("app")
      |> String.to_existing_atom()

    Application.load(app)

    app
    |> Tidy.analyze_app()
    |> Enum.map(&Tidy.errors/1)
    |> IO.puts()
  end
end
