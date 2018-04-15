defmodule Tidy.Module do
  @type t :: %__MODULE__{}
  defstruct [:id, :functions, :type, :doc, behaviors: []]
end
