defmodule TidyTest do
  use ExUnit.Case
  doctest Tidy

  test "greets the world" do
    assert Tidy.hello() == :world
  end
end
