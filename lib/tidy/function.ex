defmodule Tidy.Function do
  @type t :: %__MODULE__{}
  defstruct [:name, :arity, :spec, :args, :doc, type: :original, impl: false]
end
