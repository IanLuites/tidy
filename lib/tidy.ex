defmodule Tidy do
  @moduledoc """
  Documentation for Tidy.
  """
  alias Tidy.{Config, Inspection, Report}

  def analyze_app(app, config \\ Config.load()) do
    with {:ok, modules} <- :application.get_key(app, :modules) do
      modules
      |> Enum.reject(&(&1 in config.ignore.modules))
      |> Enum.map(&analyze(&1, config))
      |> Enum.reject(&(&1.reference.type == :protocol))
    end
  end

  def analyze(module, config \\ Config.load()) do
    with {:ok, data} <- Inspection.inspect_module(module, config) do
      report = %Report{module: module, reference: data}

      Enum.reduce(config.checks, report, &perform_check/2)
    end
  end

  def errors?(report, opts \\ [])

  def errors?(%Report{errors: errors}, opts) do
    errors.function
    |> Enum.flat_map(&elem(&1, 1))
    |> Kernel.++(errors.module)
    |> filter_check(listify(opts[:check]))
    |> filter_type(listify(opts[:type]))
    |> Enum.count()
  end

  def errors?(reports, opts) when is_list(reports) do
    reports
    |> Enum.map(&errors?(&1, opts))
    |> Enum.sum()
  end

  defp perform_check(check = {mod, _}, report) do
    perform_check(mod.scope, check, report)
  end

  defp perform_check(:module, {check, opts}, report) do
    case check.check(report.reference, opts) do
      :ok ->
        report

      {:error, short, long} ->
        error = %{
          level: opts[:level] || :error,
          short: short,
          long: long,
          type: check
        }

        %{report | errors: Map.update!(report.errors, :module, &[error | &1])}
    end
  end

  defp perform_check(:function, {check, opts}, report) do
    Enum.reduce(report.reference.functions, report, fn function, report ->
      case check.check(function, opts) do
        :ok ->
          report

        {:error, short, long} ->
          error = %{
            level: opts[:level] || :error,
            short: short,
            long: long,
            type: check
          }

          function_errors =
            Map.update(
              report.errors.function,
              {function.name, function.arity},
              [error],
              &[error | &1]
            )

          %{report | errors: Map.put(report.errors, :function, function_errors)}
      end
    end)
  end

  def output(report = %Report{}) do
    IO.puts("""
    ---
    #{report.reference.module}:
    ---
    """)
  end

  def errors(report, opts \\ [])

  def errors(reports, opts) when is_list(reports),
    do: reports |> Enum.map(&errors(&1, opts)) |> IO.iodata_to_binary()

  def errors(%Report{reference: ref, errors: errors}, opts) do
    module =
      case errors.module do
        [] ->
          ""

        errors ->
          errors
          |> filter_check(listify(opts[:check]))
          |> filter_type(listify(opts[:type]))
          |> Enum.map(fn %{short: error} -> "    #{error}" end)
          |> Enum.join("\n")
          |> Kernel.<>("\n")
      end

    function =
      case Enum.to_list(errors.function) do
        [] ->
          ""

        errors ->
          errors
          |> Enum.flat_map(fn {{fun, arity}, fun_errors} ->
            err =
              fun_errors
              |> filter_check(listify(opts[:check]))
              |> filter_type(listify(opts[:type]))
              |> Enum.map(fn %{short: error} -> "      #{error}" end)

            [
              "\n    #{IO.ANSI.cyan()}#{fun}/#{arity}#{IO.ANSI.reset()}:"
              | err
            ]
          end)
          |> Enum.join("\n")
          |> Kernel.<>("\n")
      end

    result = module <> function

    if result != "" do
      [
        [
          IO.ANSI.yellow_background(),
          "\n",
          IO.ANSI.black(),
          "  ",
          String.trim_leading("#{ref.id}", "Elixir."),
          IO.ANSI.reset()
        ],
        "\n",
        result
      ]
      |> IO.iodata_to_binary()
    else
      ""
    end
  end

  defp filter_check(list, []), do: list
  defp filter_check(list, checks), do: Enum.filter(list, &(&1.type in checks))

  defp filter_type(list, []), do: list
  defp filter_type(list, types), do: Enum.filter(list, &(&1.type.category in types))

  defp listify(nil), do: []
  defp listify(list) when is_list(list), do: list
  defp listify(item), do: [item]
end
