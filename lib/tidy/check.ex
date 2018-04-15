defmodule Tidy.Check do
  @type category :: :doc | :spec
  @type scope :: :module | :functions

  @callback scope :: scope
  @callback category :: category
  @callback default_options :: Keyword.t()
  @callback check(Tidy.Module.t() | Tidy.Function.t(), Keyword.t()) ::
              :ok | {:error, String.t(), String.t()}
end
