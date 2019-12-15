defmodule Tidy.Inspection do
  require Logger
  alias Tidy.{Module, Function}

  def inspect_module(module, config) do
    if Code.ensure_loaded?(module) do
      attributes = module.__info__(:attributes)

      doc =
        case Code.fetch_docs(module) do
          {:docs_v1, _, _, _,
           %{
             "en" => doc
           }, %{}, _} ->
            doc

          {:docs_v1, _, _, _, :hidden, %{}, _} ->
            false

          _ ->
            nil
        end

      type =
        if Keyword.has_key?(attributes, :protocol_impl) do
          :protocol
        else
          :module
        end

      context = Tidy.Impl.search(module)

      {:ok,
       %Module{
         id: module,
         type: type,
         doc: doc,
         functions: module_functions(module, config, context),
         behaviors: context.behaviors
       }}
    else
      {:error, :module_not_loaded}
    end
  end

  defp module_functions(module, config, context) do
    function_groups =
      :functions
      |> module.__info__()
      |> Enum.reject(&(&1 in config.ignore.functions))
      |> Enum.map(&inspect_function(module, &1, context))
      |> Enum.group_by(&(&1.type == :derived))

    original = Map.get(function_groups, false, [])

    function_groups
    |> Map.get(true, [])
    |> Enum.map(fn fun ->
      parent =
        original
        |> Enum.filter(&(&1.name == fun.name))
        |> Enum.filter(&(&1.arity > fun.arity))
        |> Enum.sort_by(& &1.arity)
        |> List.first()

      spec =
        if parent.spec do
          Map.update!(parent.spec, :in, &Enum.take(&1, fun.arity))
        end

      fun
      |> Map.put(:doc, parent.doc)
      |> Map.put(:impl, parent.impl)
      |> Map.put(:spec, spec)
      |> Map.put(:args, Enum.take(parent.args, fun.arity))
    end)
    |> Kernel.++(original)
    |> Enum.sort_by(& &1.name)
  end

  defp inspect_function(module, fun = {name, arity}, context) do
    {args, doc} =
      with {:docs_v1, _, _, _, _, %{}, docs} <- Code.fetch_docs(module),
           docs <- Enum.filter(docs, &(elem(elem(&1, 0), 0) == :function)),
           {{:function, _, ^arity}, _, signature, %{"en" => doc}, %{}} <-
             Enum.find(docs, &(elem(elem(&1, 0), 1) == name && elem(elem(&1, 0), 2) == arity)) do
        {generate_arguments(signature), doc}
      else
        {{:function, _, _}, _, signature, _, %{deprecated: doc}} ->
          {generate_arguments(signature), doc}

        {{:function, _, _}, _, signature, :hidden, %{}} ->
          {generate_arguments(signature), false}

        {{:function, _, _}, _, signature, :none, %{}} ->
          {generate_arguments(signature), nil}

        nil ->
          {:derived, nil}
      end

    spec =
      with {:ok, specs} = Tidy.Typespec.fetch_specs(module),
           {^fun, spec} <- List.keyfind(specs, fun, 0) do
        parse_type_spec(spec)
      else
        _ -> nil
      end

    type =
      cond do
        args == :derived -> :derived
        {name, arity} in context.delegates -> :delegate
        :original -> :original
      end

    %Function{
      name: name,
      arity: arity,
      spec: spec,
      args: args,
      doc: doc,
      type: type,
      impl: Map.get(context.impl, {name, arity}, false)
    }
  end

  defp generate_arguments(arity) when is_integer(arity) do
    0..arity |> Enum.map(&%{name: "arg#{&1}"}) |> List.delete(0)
  end

  defp generate_arguments([signature]) when is_binary(signature) do
    signature = String.replace(signature, ~r/\{[^\}]*\}/, "")

    with [_, args] <- Regex.run(~r/.+\((.+)\)/, signature) do
      args
      |> String.split(~r/, ?/)
      |> Enum.map(fn arg ->
        case String.split(arg, ~r/ *\\\\ */) do
          [name] -> %{name: name}
          [name, default] -> %{name: name, default: default}
        end
      end)
    else
      _ -> []
    end
  end

  defp parse_type_spec(nil), do: nil

  defp parse_type_spec([{:type, _, :fun, [{:type, _, :product, input}, output]}]) do
    %{
      in: parse_spec(input),
      out: parse_spec(output)
    }
  end

  defp parse_type_spec([_, _, _]) do
    # Protocol
    %{
      in: [],
      out: []
    }
  end

  defp parse_type_spec(spec) do
    Logger.warn(fn -> "Un-parsable spec: #{inspect(spec)}" end)
    nil
  end

  defp parse_spec([type]), do: parse_spec(type)
  defp parse_spec(type) when is_list(type), do: Enum.map(type, &parse_spec/1)
  defp parse_spec(atom) when is_atom(atom), do: atom
  defp parse_spec({:remote_type, _, [{:atom, _, mod}, {:atom, _, type}, []]}), do: {mod, type}
  defp parse_spec({:user_type, _, type, []}), do: {:need_module, type}
  defp parse_spec({:type, _, type, []}) when is_atom(type), do: type
  defp parse_spec({:atom, _, atom}), do: atom
  defp parse_spec({:type, _, :union, types}), do: Enum.map(types, &parse_spec/1)
  defp parse_spec({:integer, _, value}), do: value
  defp parse_spec({:type, _, :map, map_type}), do: {:map, map_type}
  defp parse_spec({:type, _, :list, map_type}), do: {:list, map_type}
  defp parse_spec({:ann_type, _, [_ann, type]}), do: parse_spec(type)

  defp parse_spec({:type, _, :tuple, :any}), do: :tuple

  defp parse_spec({:type, _, :tuple, value}),
    do: value |> Enum.map(&parse_spec/1) |> List.to_tuple()

  defp parse_spec(_what) do
    nil
  end
end
