defmodule Tidy.Checks.FunctionArgumentDocumentation do
  @moduledoc ~S"""
  """
  alias Tidy.Function
  @behaviour Tidy.Check

  @defaults [
    level: :warning,
    exceptions: ~w(opts options)
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
  def check(%Function{args: []}, _opts), do: :ok

  def check(%Function{doc: doc, args: args}, opts) do
    args =
      args |> Enum.map(&String.downcase(to_string(&1.name))) |> Kernel.--(opts[:exceptions] || [])

    doc = String.downcase(doc)

    missing = Enum.reject(args, &String.contains?(doc, &1))

    if missing == [] do
      :ok
    else
      {:error, "Not all function arguments mentioned in doc.",
       """
       Not all arguments were mentioned in the function documentation.

       Please add a reference or description of the following arguments:
       #{Enum.map_join(missing, "\n", &"  - #{&1}")}
       """}
    end
  end
end
