defmodule Tidy.Report.Errors do
  defstruct module: [],
            function: %{}
end

defmodule Tidy.Report do
  @moduledoc """
  """
  defstruct [
    :module,
    :reference,
    errors: %Tidy.Report.Errors{}
  ]
end
