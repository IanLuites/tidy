defmodule Tidy.Checks.FunctionExamples do
  @moduledoc ~S"""
  """
  alias Tidy.Function
  @behaviour Tidy.Check

  @defaults [
    level: :suggest
  ]

  @impl Tidy.Check
  def scope, do: :function

  @impl Tidy.Check
  def category, do: :doc

  @impl Tidy.Check
  def default_options, do: @defaults

  @impl Tidy.Check
  def check(%Function{type: :derived}, _opts), do: :ok
  def check(%Function{doc: nil}, _opts), do: :ok
  def check(%Function{doc: false}, _opts), do: :ok

  def check(%Function{doc: doc}, _opts) do
    if String.contains?(String.downcase(doc), "## example") do
      :ok
    else
      {:error, "Missing function examples.",
       """
       No example section was detected in the function documentation.

       Please add an an section (`## Examples`) describing showing example function calls.
       """}
    end
  end
end
