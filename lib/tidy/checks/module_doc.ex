defmodule Tidy.Checks.ModuleDoc do
  @moduledoc ~S"""
  """
  alias Tidy.Module
  @behaviour Tidy.Check
  @defaults [
    level: :error
  ]

  @impl Tidy.Check
  def scope, do: :module

  @impl Tidy.Check
  def category, do: :doc

  @impl Tidy.Check
  def default_options, do: @defaults

  @impl Tidy.Check
  def check(%Module{doc: nil}, _opts), do: {:error, "Missing module doc.", "Missing module doc."}
  def check(%Module{doc: _}, _opts), do: :ok
end
