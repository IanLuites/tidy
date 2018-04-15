defmodule Tidy.Config do
  @checks [
            Tidy.Checks.DescribeOptions,
            Tidy.Checks.FunctionArgumentDocumentation,
            Tidy.Checks.FunctionDoc,
            Tidy.Checks.FunctionExamples,
            Tidy.Checks.FunctionSpec,
            Tidy.Checks.ImplementationMentionBehavior,
            Tidy.Checks.ModuleDoc
          ]
          |> Enum.map(&{&1, &1.default_options})

  @config_file "./.tidy.exs"

  @default_ignore_functions [
    __struct__: 0,
    __struct__: 1,
    __changeset__: 0,
    __schema__: 1,
    __schema__: 2
  ]

  def load do
    config = load_from_file()
    ignore = Map.get(config, :ignore, %{})

    %{
      checks: Map.get(config, :checks, @checks),
      ignore: %{
        modules: Map.get(ignore, :modules, []),
        functions: Map.get(ignore, :functions, @default_ignore_functions)
      }
    }
  end

  def generate! do
    File.write!(@config_file, Code.format_string!(Macro.to_string(load())))
    IO.puts("Config written to: #{@config_file}")
  end

  ### Helpers ###

  defp load_from_file do
    with {:ok, data} <- File.read(@config_file),
         {tidy_config, []} <- Code.eval_string(data) do
      tidy_config
      |> Map.update(:checks, nil, &clean_checks/1)
    else
      _ -> %{}
    end
  end

  defp clean_checks(checks) do
    checks
    |> Enum.map(fn
      {m, config} -> {m, Keyword.merge(m.default_options, config)}
      {m} -> {m, m.default_options}
      m -> {m, m.default_options}
    end)
  end
end
