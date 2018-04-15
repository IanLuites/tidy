defmodule Tidy.Inspection do
  alias Tidy.{Module, Function}

  def inspect_module(module, config) do
    if Code.ensure_loaded?(module) do
      attributes = module.__info__(:attributes)

      doc =
        case Code.get_docs(module, :moduledoc) do
          {_, doc} -> doc
          _ -> nil
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
      with docs <- Code.get_docs(module, :docs),
           {^fun, _line, :def, args, doc} <- List.keyfind(docs, fun, 0) do
        {Enum.map(args, &parse_arg/1), doc}
      else
        nil -> {:derived, nil}
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

  defp parse_arg({:\\, [], [{name, [], _}, default]}) do
    %{name: name, default: default}
  end

  defp parse_arg({name, [], _}) do
    %{name: name}
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
