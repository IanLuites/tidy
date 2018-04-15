defmodule Tidy.Impl do
  @base %{behaviors: [], impl: [], delegates: []}

  def search(module) do
    :compile
    |> module.__info__()
    |> Keyword.get(:source)
    |> fetch_impl
    |> Map.get(module, @base)
    |> Map.update!(:impl, &Enum.into(&1, %{}))
  end

  defp fetch_impl(nil), do: %{}

  defp fetch_impl(file) do
    with {:ok, data} <- File.read(file),
         {:ok, code} <- Code.string_to_quoted(data) do
      code
      |> parse_ast()
      |> Map.get(:result)
    else
      _ -> %{}
    end
  end

  defp parse_ast(ast, context \\ %{result: %{}, current: %{module: [], impl: nil}})

  defp parse_ast(ast, context) when is_list(ast) do
    Enum.reduce(ast, context, &parse_ast/2)
  end

  defp parse_ast({:__block__, [], code}, context) do
    parse_ast(code, context)
  end

  defp parse_ast({:defmodule, _, [name, [{:do, code}]]}, context) do
    mod = Macro.expand(name, __ENV__)
    context = push_module(context, mod)

    code
    |> parse_ast(context)
    |> pop_module()
  end

  defp parse_ast({:@, _, [annotation]}, context) do
    case parse_annotation(annotation) do
      {:behavior, behavior} -> add_behavior(context, behavior)
      {:impl, impl} -> push_impl(context, impl)
      _ -> context
    end
  end

  defp parse_ast({:def, _, [{name, _, args}, _]}, context) do
    if impl = current_impl(context) do
      context
      |> add_impl({{name, Enum.count(args || [])}, impl})
      |> pop_impl
    else
      context
    end
  end

  defp parse_ast({:defdelegate, _, [{name, _, args}, _]}, context) do
    if impl = current_impl(context) do
      context
      |> add_impl({{name, Enum.count(args || [])}, impl})
      |> pop_impl
      |> add_delegate({name, Enum.count(args || [])})
    else
      add_delegate(context, {name, Enum.count(args || [])})
    end
  end

  defp parse_ast({ignore, _, _}, context) when ignore in ~w(alias defp defmacro defmacrop)a do
    context
  end

  defp parse_ast({_, _, _}, context), do: context

  defp parse_annotation({:spec, _, _}), do: {:spec, :ignore}

  defp parse_annotation({:behaviour, _, behavior}) do
    case behavior do
      [{:__aliases__, _, m}] -> {:behavior, Module.concat(m)}
    end
  end

  defp parse_annotation({:impl, _, impl}) do
    case impl do
      [{:__aliases__, _, m}] -> {:impl, Module.concat(m)}
      [true] -> {:impl, true}
    end
  end

  defp parse_annotation({type, _, _}), do: {type, :ignore}

  defp push_module(context, module) do
    %{context | current: Map.update!(context.current, :module, &[module | &1])}
  end

  defp pop_module(context) do
    %{context | current: Map.update!(context.current, :module, fn [_ | t] -> t end)}
  end

  defp push_impl(context, impl) do
    %{context | current: Map.put(context.current, :impl, impl)}
  end

  defp pop_impl(context) do
    %{context | current: Map.put(context.current, :impl, nil)}
  end

  defp current_module(%{current: %{module: module}}) do
    module
    |> Enum.reverse()
    |> Module.concat()
  end

  defp current_impl(%{current: %{impl: impl}}), do: impl

  defp add_behavior(context = %{result: result}, behavior) do
    mod =
      result
      |> Map.get(current_module(context), @base)
      |> Map.update!(:behaviors, &[behavior | &1])

    %{context | result: Map.put(result, current_module(context), mod)}
  end

  defp add_impl(context = %{result: result}, impl) do
    mod =
      result
      |> Map.get(current_module(context), @base)
      |> Map.update!(:impl, &[impl | &1])

    %{context | result: Map.put(result, current_module(context), mod)}
  end

  defp add_delegate(context = %{result: result}, delegate) do
    mod =
      result
      |> Map.get(current_module(context), @base)
      |> Map.update!(:delegates, &[delegate | &1])

    %{context | result: Map.put(result, current_module(context), mod)}
  end
end
