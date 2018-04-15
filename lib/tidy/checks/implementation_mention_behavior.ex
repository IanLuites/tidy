defmodule Tidy.Checks.ImplementationMentionBehavior do
  @moduledoc ~S"""
  """
  alias Tidy.Function
  @behaviour Tidy.Check

  @defaults [
    level: :warning,
    args: ~w(opts options)a
  ]

  @impl Tidy.Check
  def scope, do: :function

  @impl Tidy.Check
  def category, do: :impl

  @impl Tidy.Check
  def default_options, do: @defaults

  @impl Tidy.Check
  def check(%Function{type: :derived}, _opts), do: :ok

  def check(%Function{impl: true}, _opts) do
    {:error, "@impl should mention behavior not just `true`.",
     """
     There are two ways to indicate a function is a behavior implementation.

     - @impl true
     - @impl <behavior name) (e.g. @impl Plug)

     Please use the second method to indicate, which behavior the function belongs to.
     """}
  end

  def check(%Function{}, _opts), do: :ok
end
