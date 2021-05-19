defmodule Mix.Tasks.Tidy do
  use Mix.Task

  @shortdoc "Run tidy analysis."
  @moduledoc @shortdoc

  @doc false
  def run(_argv) do
    Mix.Task.run("compile")

    app =
      ~r/app: *:([a-z\_]+)/
      |> Regex.scan(File.read!("./mix.exs"), capture: :all_but_first)
      |> Enum.find_value(&try_load/1)

    app
    |> Tidy.analyze_app()
    |> Enum.map(&Tidy.errors/1)
    |> IO.puts()
  end

  defp try_load(app)

  defp try_load([app]) do
    name = String.to_existing_atom(app)

    if Application.ensure_loaded(name) == :ok, do: name
  rescue
    _ -> nil
  end
end
