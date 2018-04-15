defmodule Tidy.Checks.FunctionSpec do
  @moduledoc ~S"""
  """
  alias Tidy.Function
  @behaviour Tidy.Check

  @defaults [
    level: :error
  ]

  @impl Tidy.Check
  def scope, do: :function

  @impl Tidy.Check
  def category, do: :spec

  @impl Tidy.Check
  def default_options, do: @defaults

  @impl Tidy.Check
  def check(%Function{type: :derived}, _opts), do: :ok
  def check(%Function{type: :delegate}, _opts), do: :ok

  def check(%Function{spec: nil, impl: false}, _opts),
    do: {:error, "Missing function spec.", "Missing function spec."}

  def check(%Function{doc: _}, _opts), do: :ok
end
