defmodule Tidy.Checks.DescribeOptions do
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
  def category, do: :doc

  @impl Tidy.Check
  def default_options, do: @defaults

  @impl Tidy.Check
  def check(%Function{type: :derived}, _opts), do: :ok
  def check(%Function{doc: nil}, _opts), do: :ok
  def check(%Function{spec: nil}, _opts), do: :ok
  def check(%Function{args: []}, _opts), do: :ok
  def check(%Function{doc: false}, _opts), do: :ok

  def check(%Function{doc: doc, spec: spec, args: args}, opts) do
    option_names = opts[:args] || []

    with %{default: []} <- Enum.find(args, &(&1.name in option_names)),
         index <- Enum.find_index(args, &(&1.name in option_names)),
         {Keyword, :t} <- Enum.at(spec.in, index),
         false <- String.contains?(String.downcase(doc), "## options") do
      {:error, "Missing options description.",
       """
       Options were detected in the function arguments.

       Please add an options section (`## Options`) describing all possible options.
       """}
    else
      _ -> :ok
    end
  end
end
