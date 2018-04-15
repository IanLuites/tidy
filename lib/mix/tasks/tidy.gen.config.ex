defmodule Mix.Tasks.Tidy.Gen.Config do
  use Mix.Task

  @shortdoc "Generate example config"
  @moduledoc @shortdoc

  @doc false
  def run(_argv) do
    Tidy.Config.generate!()
  end
end
